// radio/Core/Support/QdrantConfig.swift

import Foundation
import FirebaseFirestore

struct PodcastTranscriptSegment: Identifiable, Hashable {
    let id: Int
    let chunkIndex: Int
    let startSeconds: Double
    let endSeconds: Double
    let text: String
}

struct QdrantEpisodeMatch {
    let episode: PodcastEpisode
    let score: Double
    let snippet: String?
    /// Exact second where playback should start (already 3 seconds before the matched word/phrase).
    let startSeconds: Double?
    let matchedChunkIndex: Int?
}

/// Configuración y cliente REST de Qdrant para indexación y búsqueda BM25 de podcasts.
enum QdrantConfig {
    /// URL del clúster de Qdrant Cloud
    nonisolated static let fallbackClusterURL: String = "https://911356d3-0c20-4d27-a9e0-64d525402b4c.us-east-1-1.aws.cloud.qdrant.io:6333"
    /// API Key de Qdrant Cloud
    nonisolated static let fallbackApiKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIiwic3ViamVjdCI6ImFwaS1rZXk6N2EzNjFiNDktODRjOC00Y2JmLWFkNzAtOGY3Y2VkODUyN2M0In0.u2Q91Be-pJkouR2vxn42XpTdwVylVQu-O6f61xX-jBE"
    /// Nombre de la colección en Qdrant
    nonisolated static let collectionName: String = "podcast_segments"
    /// Segundos de anticipación antes de que se mencione la palabra buscada
    nonisolated static let leadInSeconds: Double = 3.0

    nonisolated(unsafe) private static var cachedCredentials: (url: URL, apiKey: String)?
    nonisolated(unsafe) private static var didAttemptRemoteLoad = false
    nonisolated(unsafe) private static var syncedPodcastIds = Set<String>()
    nonisolated(unsafe) private static var didEnsureCollection = false

    /// Obtiene las credenciales desde `fallbackClusterURL` o desde `config/app` en Firestore.
    static func resolveCredentials() async -> (url: URL, apiKey: String)? {
        if let cachedCredentials { return cachedCredentials }

        let localURLText = fallbackClusterURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let localKey = fallbackApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !localURLText.isEmpty, !localKey.isEmpty, let url = URL(string: cleanBaseURL(localURLText)) {
            let creds = (url: url, apiKey: localKey)
            cachedCredentials = creds
            return creds
        }

        guard !didAttemptRemoteLoad else { return nil }
        didAttemptRemoteLoad = true

        do {
            let doc = try await Firestore.firestore().collection("config").document("app").getDocument()
            guard let data = doc.data(),
                  let remoteURLText = (data["qdrantUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let remoteKey = (data["qdrantApiKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !remoteURLText.isEmpty,
                  !remoteKey.isEmpty,
                  let url = URL(string: cleanBaseURL(remoteURLText)) else {
                return nil
            }
            let creds = (url: url, apiKey: remoteKey)
            cachedCredentials = creds
            return creds
        } catch {
            return nil
        }
    }

    private nonisolated static func cleanBaseURL(_ raw: String) -> String {
        raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }

    // MARK: - Hash FNV-1a de 31 bits y Vectorizador Disperso BM25 (Idéntico al Panel Web)

    nonisolated static func fnv1a31(_ text: String) -> Int {
        var hash: UInt32 = 0x811c9dc5
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return Int(hash & 0x7fffffff)
    }

    nonisolated static func buildBM25SparseVector(from text: String) -> (indices: [Int], values: [Double]) {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
        let tokens = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 && !BuscarViewModel.stopwords.contains($0) }

        var counts: [Int: Double] = [:]
        for token in tokens {
            let exactIdx = fnv1a31(token)
            counts[exactIdx, default: 0] += 1.0
            if token.count >= 5 {
                let stem = String(token.prefix(5))
                let stemIdx = fnv1a31("stem:\(stem)")
                counts[stemIdx, default: 0] += 0.65
            }
        }

        var indices: [Int] = []
        var values: [Double] = []
        indices.reserveCapacity(counts.count)
        values.reserveCapacity(counts.count)

        for (idx, tf) in counts {
            indices.append(idx)
            values.append(1.0 + log(tf))
        }
        return (indices, values)
    }

    // MARK: - Búsqueda agrupada por episodio en Qdrant (/points/query/groups)

    static func searchPodcasts(
        terms: [String],
        programMeta: [String: PodcastProgramMeta]
    ) async throws -> [QdrantEpisodeMatch]? {
        guard let creds = await resolveCredentials() else { return nil }

        let queryText = terms.joined(separator: " ")
        let sparse = buildBM25SparseVector(from: queryText)
        guard !sparse.indices.isEmpty else { return [] }

        let endpoint = creds.url.appendingPathComponent("collections/\(collectionName)/points/query/groups")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(creds.apiKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = 8

        let body: [String: Any] = [
            "query": [
                "indices": sparse.indices,
                "values": sparse.values
            ],
            "using": "bm25",
            "group_by": "podcastId",
            "group_size": 1,
            "limit": 20,
            "with_payload": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultObj = json["result"] as? [String: Any],
              let groups = resultObj["groups"] as? [[String: Any]] else {
            return nil
        }

        var matches: [QdrantEpisodeMatch] = []
        for group in groups {
            guard let hits = group["hits"] as? [[String: Any]],
                  let topHit = hits.first,
                  let payload = topHit["payload"] as? [String: Any],
                  let podcastId = payload["podcastId"] as? String,
                  let programName = payload["programName"] as? String,
                  let audioId = DriveLink.fileId(from: payload["audioUrl"] as? String) ?? (payload["audioId"] as? String) else {
                continue
            }

            let score = (topHit["score"] as? Double) ?? 1.0
            let programId = payload["programId"] as? String ?? ""
            let airDateSeconds = (payload["airDate"] as? Double) ?? Date.now.timeIntervalSince1970
            let airTime = payload["airTime"] as? String ?? ""
            let info = programMeta[programId]
            let hosts = (payload["hosts"] as? [String]) ?? info?.hosts ?? []
            let rawImageId = DriveLink.fileId(from: payload["imageUrl"] as? String)
                ?? (payload["imageId"] as? String)
            let imageId = (rawImageId?.isEmpty == false ? rawImageId : nil) ?? info?.imageId
            let snippet = (payload["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let chunkIndex = payload["chunkIndex"] as? Int

            // Calcular el segundo exacto donde se menciona la palabra dentro del fragmento y restar 3 segundos
            let chunkStart = (payload["startSeconds"] as? Double)
                ?? Double(chunkIndex ?? 0) * (35.0 / 2.5)
            let chunkEnd = (payload["endSeconds"] as? Double)
                ?? (chunkStart + (45.0 / 2.5))

            let wordSecond = interpolateWordTimestamp(
                in: snippet ?? "",
                terms: terms,
                chunkStart: chunkStart,
                chunkEnd: chunkEnd
            )
            let playbackStart = max(0, wordSecond - leadInSeconds)

            let episode = PodcastEpisode(
                id: podcastId,
                programId: programId,
                programName: programName,
                airDate: Date(timeIntervalSince1970: airDateSeconds),
                airTime: airTime,
                hosts: hosts,
                imageId: imageId,
                audioId: audioId
            )
            matches.append(
                QdrantEpisodeMatch(
                    episode: episode,
                    score: score,
                    snippet: snippet,
                    startSeconds: playbackStart,
                    matchedChunkIndex: chunkIndex
                )
            )
        }
        return matches
    }

    /// Obtiene todos los fragmentos de un episodio desde Qdrant (o Firestore) ordenados cronológicamente.
    static func fetchEpisodeSegments(podcastId: String) async -> [PodcastTranscriptSegment] {
        if let creds = await resolveCredentials() {
            let endpoint = creds.url.appendingPathComponent("collections/\(collectionName)/points/scroll")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(creds.apiKey, forHTTPHeaderField: "api-key")
            request.timeoutInterval = 8

            let body: [String: Any] = [
                "filter": [
                    "must": [
                        [
                            "key": "podcastId",
                            "match": ["value": podcastId]
                        ]
                    ]
                ],
                "limit": 400,
                "with_payload": true,
                "with_vector": false
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resultObj = json["result"] as? [String: Any],
               let points = resultObj["points"] as? [[String: Any]],
               !points.isEmpty {
                let segments: [PodcastTranscriptSegment] = points.compactMap { pt in
                    guard let payload = pt["payload"] as? [String: Any],
                          let text = payload["text"] as? String else { return nil }
                    let idx = (payload["chunkIndex"] as? Int) ?? 0
                    let start = (payload["startSeconds"] as? Double) ?? Double(idx) * (35.0 / 2.5)
                    let end = (payload["endSeconds"] as? Double) ?? (start + (45.0 / 2.5))
                    return PodcastTranscriptSegment(
                        id: idx,
                        chunkIndex: idx,
                        startSeconds: start,
                        endSeconds: end,
                        text: text
                    )
                }
                .sorted { $0.chunkIndex < $1.chunkIndex }

                if !segments.isEmpty {
                    return segments
                }
            }
        }

        // Respaldo desde Firestore si Qdrant no responde
        do {
            let doc = try await Firestore.firestore().collection("podcasts").document(podcastId).getDocument()
            let transcript = doc.data()?["transcript"] as? String ?? ""
            let words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
            let chunkSize = 45
            let step = 35
            var result: [PodcastTranscriptSegment] = []
            var i = 0
            var idx = 0
            while i < words.count {
                let end = min(i + chunkSize, words.count)
                let startSecs = Double(i) / 2.5
                let endSecs = Double(end) / 2.5
                result.append(
                    PodcastTranscriptSegment(
                        id: idx,
                        chunkIndex: idx,
                        startSeconds: startSecs,
                        endSeconds: endSecs,
                        text: words[i..<end].joined(separator: " ")
                    )
                )
                if end == words.count { break }
                i += step
                idx += 1
            }
            return result
        } catch {
            return []
        }
    }

    /// Calcula el segundo dentro del fragmento en el que aparece la palabra buscada.
    nonisolated static func interpolateWordTimestamp(
        in chunkText: String,
        terms: [String],
        chunkStart: Double,
        chunkEnd: Double
    ) -> Double {
        if let explicit = parseTimestampSeconds(in: chunkText) {
            return explicit
        }
        let words = chunkText.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty, !terms.isEmpty else { return chunkStart }

        for (index, rawWord) in words.enumerated() {
            let clean = rawWord
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .lowercased()
                .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            for term in terms {
                if clean == term || (term.count >= 4 && clean.hasPrefix(term)) {
                    let ratio = Double(index) / Double(max(words.count, 1))
                    let duration = max(chunkEnd - chunkStart, 0)
                    return chunkStart + ratio * duration
                }
            }
        }
        return chunkStart
    }

    // MARK: - Sincronización automática de episodios de Firestore hacia Qdrant

    static func syncFirestoreDocumentsIfNeeded(
        documents: [QueryDocumentSnapshot],
        programMeta: [String: PodcastProgramMeta]
    ) async {
        guard let creds = await resolveCredentials() else { return }

        if !didEnsureCollection {
            await ensureCollectionExists(creds: creds)
            didEnsureCollection = true
        }

        var points: [[String: Any]] = []
        for doc in documents {
            let podcastId = doc.documentID
            guard !syncedPodcastIds.contains(podcastId) else { continue }
            guard let episode = PodcastService.episode(from: doc, programMeta: programMeta) else { continue }

            let data = doc.data()
            let transcript = (data["transcript"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let keywords = (data["keywords"] as? [String] ?? []).joined(separator: " ")
            let baseText = transcript.isEmpty ? "\(episode.programName) \(keywords)" : transcript

            let words = baseText.split(whereSeparator: \.isWhitespace).map(String.init)
            let totalWords = max(words.count, 1)
            let wordsPerSecond = 2.5
            let chunkSize = 45
            let overlap = 10
            let step = max(chunkSize - overlap, 1)

            var index = 0
            var chunkNumber = 0
            while index < words.count {
                let end = min(index + chunkSize, words.count)
                let chunkText = words[index..<end].joined(separator: " ")
                let fullContext = "\(episode.programName) \(keywords) \(chunkText)"
                let sparse = buildBM25SparseVector(from: fullContext)

                if !sparse.indices.isEmpty {
                    let startSecs = parseTimestampSeconds(in: chunkText) ?? (Double(index) / wordsPerSecond)
                    let endSecs = Double(end) / wordsPerSecond
                    let payload: [String: Any] = [
                        "podcastId": episode.id,
                        "programId": episode.programId,
                        "programName": episode.programName,
                        "airDate": episode.airDate.timeIntervalSince1970,
                        "airTime": episode.airTime,
                        "hosts": episode.hosts,
                        "imageId": episode.imageId ?? "",
                        "audioId": episode.audioId,
                        "chunkIndex": chunkNumber,
                        "text": chunkText,
                        "startSeconds": (startSecs * 10).rounded() / 10,
                        "endSeconds": (endSecs * 10).rounded() / 10,
                        "progressRatio": Double(index) / Double(totalWords)
                    ]

                    points.append([
                        "id": fnv1a31("\(episode.id)#\(chunkNumber)"),
                        "vector": [
                            "bm25": [
                                "indices": sparse.indices,
                                "values": sparse.values
                            ]
                        ],
                        "payload": payload
                    ])
                }

                if end == words.count { break }
                index += step
                chunkNumber += 1
            }
            syncedPodcastIds.insert(podcastId)
        }

        guard !points.isEmpty else { return }
        let endpoint = creds.url.appendingPathComponent("collections/\(collectionName)/points")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(creds.apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["points": points])
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                print("QdrantConfig: sincronizados \(points.count) fragmentos en podcast_segments.")
            } else {
                print("QdrantConfig: respuesta inesperada al sincronizar puntos:", response)
            }
        } catch {
            print("QdrantConfig: error sincronizando puntos:", error)
        }
    }

    private static func ensureCollectionExists(creds: (url: URL, apiKey: String)) async {
        let collectionURL = creds.url.appendingPathComponent("collections/\(collectionName)")
        var getReq = URLRequest(url: collectionURL)
        getReq.httpMethod = "GET"
        getReq.setValue(creds.apiKey, forHTTPHeaderField: "api-key")

        if let (_, resp) = try? await URLSession.shared.data(for: getReq),
           let http = resp as? HTTPURLResponse,
           http.statusCode == 200 {
            return
        }

        var createReq = URLRequest(url: collectionURL)
        createReq.httpMethod = "PUT"
        createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createReq.setValue(creds.apiKey, forHTTPHeaderField: "api-key")
        let createBody: [String: Any] = [
            "vectors": [:],
            "sparse_vectors": [
                "bm25": [
                    "modifier": "idf"
                ]
            ]
        ]
        createReq.httpBody = try? JSONSerialization.data(withJSONObject: createBody)
        _ = try? await URLSession.shared.data(for: createReq)

        let indexURL = creds.url.appendingPathComponent("collections/\(collectionName)/index")
        var indexReq = URLRequest(url: indexURL)
        indexReq.httpMethod = "PUT"
        indexReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        indexReq.setValue(creds.apiKey, forHTTPHeaderField: "api-key")
        let indexBody: [String: Any] = [
            "field_name": "podcastId",
            "field_schema": "keyword"
        ]
        indexReq.httpBody = try? JSONSerialization.data(withJSONObject: indexBody)
        _ = try? await URLSession.shared.data(for: indexReq)
    }

    /// Detecta marcas de tiempo opcionales como [04:15] o (12:30) dentro de un fragmento de transcripción.
    nonisolated static func parseTimestampSeconds(in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        func intAt(_ idx: Int) -> Int? {
            guard idx < match.numberOfRanges,
                  let r = Range(match.range(at: idx), in: text) else { return nil }
            return Int(text[r])
        }
        if let third = intAt(3), let h = intAt(1), let m = intAt(2) {
            return Double(h * 3600 + m * 60 + third)
        }
        if let m = intAt(1), let s = intAt(2) {
            return Double(m * 60 + s)
        }
        return nil
    }
}
