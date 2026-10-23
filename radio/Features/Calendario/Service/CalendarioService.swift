// radio/Features/Calendario/Service/CalendarioService.swift

//
//  CalendarioService.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import Foundation
import FirebaseFirestore

struct CalendarioService {
    /// Listens to the events that match the user's audience tags and reports every change.
    func observeEventos(
        audienceTags: [String],
        onChange: @escaping @MainActor ([Evento]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ListenerRegistration {
        Firestore.firestore()
            .collection("events")
            .whereField("audience", arrayContainsAny: audienceTags)
            .addSnapshotListener { snapshot, error in
                if let error {
                    MainActor.assumeIsolated { onError(error) }
                    return
                }
                guard let snapshot else { return }
                let eventos = snapshot.documents.compactMap { Self.evento(from: $0) }
                MainActor.assumeIsolated { onChange(eventos) }
            }
    }

    private nonisolated static func evento(from doc: QueryDocumentSnapshot) -> Evento? {
        let data = doc.data()
        guard let title = data["title"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue() else { return nil }

        let linkText = (data["link"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""

        return Evento(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? data["summary"] as? String ?? "",
            link: linkText.isEmpty ? nil : URL(string: linkText),
            audience: data["audience"] as? [String] ?? [],
            date: date,
            endDate: (data["endDate"] as? Timestamp)?.dateValue()
        )
    }
}
