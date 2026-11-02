// radio/Features/Buscar/Service/BuscarService.swift

import Foundation
import FirebaseFirestore

/// The programs and the events (only those for the user's profile) that can be searched.
struct SearchCatalog {
    let programs: [Programa]
    let events: [EventItem]
}

struct BuscarService {
    private var db: Firestore { Firestore.firestore() }

    func loadCatalog(audienceTags: [String]) async throws -> SearchCatalog {
        let programsSnapshot = try await db.collection("programs").getDocuments()
        let programs = programsSnapshot.documents.compactMap { Self.programa(from: $0) }

        let tags = Array((audienceTags.isEmpty ? ["todos"] : audienceTags).prefix(30))
        let eventsSnapshot = try await db.collection("events")
            .whereField("audience", arrayContainsAny: tags)
            .getDocuments()
        let events = eventsSnapshot.documents.compactMap { Self.event(from: $0) }

        return SearchCatalog(programs: programs, events: events)
    }

    private nonisolated static func programa(from doc: QueryDocumentSnapshot) -> Programa? {
        let data = doc.data()
        guard (data["active"] as? Bool) ?? true,
              let name = data["name"] as? String,
              let startTime = data["startTime"] as? String,
              let days = data["days"] as? [Int] else { return nil }

        return Programa(
            id: doc.documentID,
            name: name,
            days: days,
            startTime: startTime,
            durationMinutes: data["durationMinutes"] as? Int ?? 60,
            collective: data["collective"] as? String ?? "",
            hosts: data["hosts"] as? [String] ?? [],
            artworkDriveId: data["artworkDriveId"] as? String ?? ""
        )
    }

    private nonisolated static func event(from doc: QueryDocumentSnapshot) -> EventItem? {
        let data = doc.data()
        guard let title = data["title"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue() else { return nil }

        let linkText = (data["link"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        return EventItem(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? data["summary"] as? String ?? "",
            date: date,
            endDate: (data["endDate"] as? Timestamp)?.dateValue(),
            link: linkText.isEmpty ? nil : URL(string: linkText)
        )
    }
}
