// radio/Features/Podcast/Service/PodcastService.swift

import Foundation
import FirebaseFirestore

struct PodcastProgramMeta {
    let imageId: String?
    let hosts: [String]
}

struct PodcastSearchMatch {
    let episode: PodcastEpisode
    let matches: Int
    let snippet: String?
    let startSeconds: Double?
    let matchedChunkIndex: Int?
}

struct PodcastService {
    private var db: Firestore { Firestore.firestore() }

    /// Every episode ready to listen to, newest first.
    func listEpisodes() async throws -> [PodcastEpisode] {
        async let metaTask = Self.loadProgramMeta()
        async let snapshotTask = db.collection("podcasts")
            .whereField("status", isEqualTo: "lista")
            .getDocuments()

        let (meta, snapshot) = try await (metaTask, snapshotTask)

        let docs = snapshot.documents
        Task {
            await QdrantConfig.syncFirestoreDocumentsIfNeeded(documents: docs, programMeta: meta)
        }

        return docs
            .compactMap { Self.episode(from: $0, programMeta: meta) }
            .sorted { $0.airDate > $1.airDate }
    }

    /// Busca episodios por tema usando Qdrant (BM25 + fragmentos) validando que existan en Firestore ("lista").
    func episodes(matching terms: [String]) async throws -> [PodcastSearchMatch] {
        guard !terms.isEmpty else { return [] }

        async let metaTask = Self.loadProgramMeta()
        async let snapshotTask = db.collection("podcasts")
            .whereField("status", isEqualTo: "lista")
            .getDocuments()

        let (meta, snapshot) = try await (metaTask, snapshotTask)
        let docs = snapshot.documents
        let validIds = Set(docs.map(\.documentID))

        // 1. Intentar búsqueda vectorial BM25 agrupada en Qdrant filtrando solo episodios vigentes en Firestore
        if let qdrantHits = try? await QdrantConfig.searchPodcasts(
            terms: terms,
            programMeta: meta
        ) {
            let validHits = qdrantHits.filter { validIds.contains($0.episode.id) }
            if !validHits.isEmpty {
                return validHits.map { hit in
                    PodcastSearchMatch(
                        episode: hit.episode,
                        matches: max(Int((hit.score * 100).rounded()), 1),
                        snippet: hit.snippet,
                        startSeconds: hit.startSeconds,
                        matchedChunkIndex: hit.matchedChunkIndex
                    )
                }
            }
        }

        // 2. Respaldo en Firestore con extracción del fragmento y segundo exacto (-3 s)
        Task {
            await QdrantConfig.syncFirestoreDocumentsIfNeeded(documents: docs, programMeta: meta)
        }

        return docs.compactMap { doc in
            guard let episode = Self.episode(from: doc, programMeta: meta) else { return nil }
            let data = doc.data()
            let transcript = data["transcript"] as? String ?? ""
            let keywords = (data["keywords"] as? [String] ?? []).joined(separator: " ")
            let hostsText = episode.hosts.joined(separator: " ")

            let matchCount = BuscarViewModel.matches(
                in: [episode.programName, hostsText, keywords, transcript],
                terms: terms
            )
            guard matchCount > 0 else { return nil }

            let snippetInfo = Self.extractBestSnippetAndTime(from: transcript, terms: terms)

            return PodcastSearchMatch(
                episode: episode,
                matches: matchCount,
                snippet: snippetInfo?.snippet,
                startSeconds: snippetInfo?.startSeconds,
                matchedChunkIndex: snippetInfo?.chunkIndex
            )
        }
    }

    /// Extrae el fragmento de ~36 palabras donde mayor concentración del tema buscado hay,
    /// y calcula el segundo de inicio restando 3 segundos de anticipación.
    nonisolated static func extractBestSnippetAndTime(
        from transcript: String,
        terms: [String]
    ) -> (snippet: String, startSeconds: Double, chunkIndex: Int)? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !terms.isEmpty else { return nil }

        let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }

        let windowSize = 36
        let step = 12
        var bestRange: Range<Int>?
        var bestScore = 0
        var bestWordOffset = 0

        var start = 0
        while start < words.count {
            let end = min(start + windowSize, words.count)
            let sliceWords = Array(words[start..<end])
            let sliceText = sliceWords.joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .lowercased()
            let tokens = sliceText
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }

            var score = 0
            for term in terms {
                let termHits = tokens.filter { token in
                    token == term || (term.count >= 4 && token.hasPrefix(term))
                }.count
                if termHits > 0 {
                    score += 10 + termHits
                }
            }

            if score > bestScore {
                bestScore = score
                bestRange = start..<end
                bestWordOffset = start
            }

            if end == words.count { break }
            start += step
        }

        guard let bestRange, bestScore > 0 else { return nil }
        let prefixEllipsis = bestRange.lowerBound > 0 ? "…" : ""
        let suffixEllipsis = bestRange.upperBound < words.count ? "…" : ""
        let snippet = prefixEllipsis + words[bestRange].joined(separator: " ") + suffixEllipsis

        let rawSecond = QdrantConfig.parseTimestampSeconds(in: snippet) ?? (Double(bestWordOffset) / 2.5)
        let startSeconds = max(0, rawSecond - QdrantConfig.leadInSeconds)
        let approxChunkIndex = bestWordOffset / 35

        return (snippet: snippet, startSeconds: startSeconds, chunkIndex: approxChunkIndex)
    }

    static func loadProgramMeta() async -> [String: PodcastProgramMeta] {
        do {
            let snapshot = try await Firestore.firestore().collection("programs").getDocumentListSafely()
            var meta: [String: PodcastProgramMeta] = [:]
            for doc in snapshot {
                let data = doc.data()
                let rawId = data["artworkDriveId"] as? String ?? ""
                let hosts = data["hosts"] as? [String] ?? []
                meta[doc.documentID] = PodcastProgramMeta(
                    imageId: rawId.isEmpty ? nil : rawId,
                    hosts: hosts
                )
            }
            return meta
        } catch {
            print("PodcastService: could not load program metadata:", error)
            return [:]
        }
    }

    nonisolated static func episode(
        from doc: QueryDocumentSnapshot,
        programMeta: [String: PodcastProgramMeta]
    ) -> PodcastEpisode? {
        let data = doc.data()
        guard let programName = data["programName"] as? String,
              let airDate = (data["airDate"] as? Timestamp)?.dateValue(),
              let audioId = DriveLink.fileId(from: data["audioUrl"] as? String) else { return nil }

        let programId = data["programId"] as? String ?? ""
        let airTime = data["airTime"] as? String ?? ""
        let info = programMeta[programId]
        return PodcastEpisode(
            id: doc.documentID,
            programId: programId,
            programName: programName,
            airDate: airDate,
            airTime: airTime,
            hosts: info?.hosts ?? [],
            imageId: DriveLink.fileId(from: data["imageUrl"] as? String) ?? info?.imageId,
            audioId: audioId
        )
    }
}

private extension CollectionReference {
    func getDocumentListSafely() async throws -> [QueryDocumentSnapshot] {
        try await getDocuments().documents
    }
}
