//
//  PodcastService.swift
//  radio
//
//  Created by Foster Chacon on 30/10/26.
//

// radio/Features/Podcast/Service/PodcastService.swift

import Foundation
import FirebaseFirestore

struct PodcastService {
    private var db: Firestore { Firestore.firestore() }

    /// Every episode ready to listen to, newest first.
    func listEpisodes() async throws -> [PodcastEpisode] {
        let images = await Self.loadProgramImages()
        let snapshot = try await db.collection("podcasts")
            .whereField("status", isEqualTo: "lista")
            .getDocuments()

        return snapshot.documents
            .compactMap { Self.episode(from: $0, programImages: images) }
            .sorted { $0.airDate > $1.airDate }
    }

    /// Episodes whose transcript keywords contain at least one of the terms.
    func episodes(matching terms: [String]) async throws -> [(episode: PodcastEpisode, matches: Int)] {
        guard !terms.isEmpty else { return [] }

        let images = await Self.loadProgramImages()
        let snapshot = try await db.collection("podcasts")
            .whereField("status", isEqualTo: "lista")
            .whereField("keywords", arrayContainsAny: Array(terms.prefix(30)))
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let episode = Self.episode(from: doc, programImages: images) else { return nil }
            let keywords = Set(doc.data()["keywords"] as? [String] ?? [])
            return (episode: episode, matches: terms.filter { keywords.contains($0) }.count)
        }
    }

    /// Episodes of the given programs. The status is filtered here to avoid a composite index.
    func episodes(programIds: [String]) async throws -> [PodcastEpisode] {
        let ids = Array(programIds.prefix(30))
        guard !ids.isEmpty else { return [] }

        let images = await Self.loadProgramImages()
        let snapshot = try await db.collection("podcasts")
            .whereField("programId", in: ids)
            .getDocuments()

        return snapshot.documents
            .filter { ($0.data()["status"] as? String) == "lista" }
            .compactMap { Self.episode(from: $0, programImages: images) }
    }

    /// programId -> image of the program, used when an episode has no image of its own.
    static func loadProgramImages() async -> [String: String] {
        do {
            let snapshot = try await Firestore.firestore().collection("programs").getDocuments()
            var images: [String: String] = [:]
            for doc in snapshot.documents {
                if let id = doc.data()["artworkDriveId"] as? String, !id.isEmpty {
                    images[doc.documentID] = id
                }
            }
            return images
        } catch {
            print("PodcastService: could not load program images:", error)
            return [:]
        }
    }

    nonisolated static func episode(
        from doc: QueryDocumentSnapshot,
        programImages: [String: String]
    ) -> PodcastEpisode? {
        let data = doc.data()
        guard let programName = data["programName"] as? String,
              let airDate = (data["airDate"] as? Timestamp)?.dateValue(),
              let audioId = DriveLink.fileId(from: data["audioUrl"] as? String) else { return nil }

        let programId = data["programId"] as? String ?? ""
        return PodcastEpisode(
            id: doc.documentID,
            programId: programId,
            programName: programName,
            airDate: airDate,
            imageId: DriveLink.fileId(from: data["imageUrl"] as? String) ?? programImages[programId],
            audioId: audioId
        )
    }
}
