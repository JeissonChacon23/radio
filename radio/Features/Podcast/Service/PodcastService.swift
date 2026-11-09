// radio/Features/Podcast/Service/PodcastService.swift

import Foundation
import FirebaseFirestore

struct PodcastProgramMeta {
    let imageId: String?
    let hosts: [String]
}

struct PodcastService {
    private var db: Firestore { Firestore.firestore() }

    /// Every episode ready to listen to, newest first.
    func listEpisodes() async throws -> [PodcastEpisode] {
        let meta = await Self.loadProgramMeta()
        let snapshot = try await db.collection("podcasts")
            .whereField("status", isEqualTo: "lista")
            .getDocuments()

        return snapshot.documents
            .compactMap { Self.episode(from: $0, programMeta: meta) }
            .sorted { $0.airDate > $1.airDate }
    }

    /// I6 & I7: Searches across the full normalized transcript, keywords, and program name.
    /// Requires all searched terms to match so only truly relevant episodes are returned.
    func episodes(matching terms: [String]) async throws -> [(episode: PodcastEpisode, matches: Int)] {
        guard !terms.isEmpty else { return [] }

        let meta = await Self.loadProgramMeta()
        let snapshot = try await db.collection("podcasts")
            .whereField("status", isEqualTo: "lista")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
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
            return (episode: episode, matches: matchCount)
        }
    }

    static func loadProgramMeta() async -> [String: PodcastProgramMeta] {
        do {
            let snapshot = try await Firestore.firestore().collection("programs").getDocuments()
            var meta: [String: PodcastProgramMeta] = [:]
            for doc in snapshot.documents {
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
