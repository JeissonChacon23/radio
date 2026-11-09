// radio/Features/Buscar/Service/BuscarService.swift

import Foundation
import FirebaseFirestore

struct SearchCatalog {
    let programs: [Programa]
    let events: [EventItem]
}

struct BuscarService {
    private var db: Firestore { Firestore.firestore() }

    func loadCatalog(profile: UserProfile?) async throws -> SearchCatalog {
        let programsSnapshot = try await db.collection("programs").getDocuments()
        let programs = programsSnapshot.documents.compactMap { Self.programa(from: $0) }

        let effectiveProfile = profile ?? UserProfile(profileType: .invitado, careerId: nil)
        let tags = Array(effectiveProfile.audienceTags.prefix(30))
        let eventsSnapshot = try await db.collection("events")
            .whereField("audience", arrayContainsAny: tags)
            .getDocuments()
        let events = eventsSnapshot.documents.compactMap { doc -> EventItem? in
            let audience = doc.data()["audience"] as? [String] ?? []
            guard effectiveProfile.matches(eventAudience: audience) else { return nil }
            return Self.event(from: doc)
        }

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
        let specialGuest = (data["specialGuest"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let startTime = (data["startTime"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let endTime = (data["endTime"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""

        return EventItem(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? data["summary"] as? String ?? "",
            specialGuest: specialGuest,
            startTime: startTime,
            endTime: endTime,
            date: date,
            endDate: (data["endDate"] as? Timestamp)?.dateValue(),
            link: linkText.isEmpty ? nil : URL(string: linkText)
        )
    }
}
