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
        let effectiveProfile = profile ?? UserProfile(profileType: .invitado, careerId: nil)
        let tags = Array(effectiveProfile.audienceTags.prefix(30))

        async let programsTask = db.collection("programs").getDocuments()
        async let eventsTask = db.collection("events")
            .whereField("audience", arrayContainsAny: tags)
            .getDocuments()

        let (programsSnapshot, eventsSnapshot) = try await (programsTask, eventsTask)

        let programs = programsSnapshot.documents.compactMap { ProgramacionService.programa(from: $0) }
        let events = eventsSnapshot.documents.compactMap { doc -> EventItem? in
            let audience = doc.data()["audience"] as? [String] ?? []
            guard effectiveProfile.matches(eventAudience: audience) else { return nil }
            return Self.event(from: doc)
        }

        return SearchCatalog(programs: programs, events: events)
    }

    private nonisolated static func event(from doc: QueryDocumentSnapshot) -> EventItem? {
        let data = doc.data()
        guard (data["active"] as? Bool) ?? true,
              let title = data["title"] as? String,
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
