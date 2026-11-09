// radio/Features/Calendario/Service/CalendarioService.swift

import Foundation
import FirebaseFirestore

struct CalendarioService {
    /// Listens to the events that match the user's profile, department or program.
    func observeEventos(
        profile: UserProfile,
        onChange: @escaping @MainActor ([Evento]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ListenerRegistration {
        let tags = Array(profile.audienceTags.prefix(30))
        return Firestore.firestore()
            .collection("events")
            .whereField("audience", arrayContainsAny: tags)
            .addSnapshotListener { snapshot, error in
                if let error {
                    MainActor.assumeIsolated { onError(error) }
                    return
                }
                guard let snapshot else { return }
                let eventos = snapshot.documents
                    .compactMap { Self.evento(from: $0) }
                    .filter { profile.matches(eventAudience: $0.audience) }
                MainActor.assumeIsolated { onChange(eventos) }
            }
    }

    private nonisolated static func evento(from doc: QueryDocumentSnapshot) -> Evento? {
        let data = doc.data()
        guard let title = data["title"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue() else { return nil }

        let linkText = (data["link"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let specialGuest = (data["specialGuest"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let startTime = (data["startTime"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let endTime = (data["endTime"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""

        return Evento(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? data["summary"] as? String ?? "",
            specialGuest: specialGuest,
            startTime: startTime,
            endTime: endTime,
            link: linkText.isEmpty ? nil : URL(string: linkText),
            audience: data["audience"] as? [String] ?? [],
            date: date,
            endDate: (data["endDate"] as? Timestamp)?.dateValue()
        )
    }
}
