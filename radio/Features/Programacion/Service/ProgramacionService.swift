// radio/Features/Programacion/Service/ProgramacionService.swift

//
//  ProgramacionService.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import Foundation
import FirebaseFirestore

struct ProgramacionService {
    func observeProgramas(
        onChange: @escaping @MainActor ([Programa]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ListenerRegistration {
        Firestore.firestore()
            .collection("programs")
            .addSnapshotListener { snapshot, error in
                if let error {
                    MainActor.assumeIsolated { onError(error) }
                    return
                }
                guard let snapshot else { return }
                let programas = snapshot.documents.compactMap { Self.programa(from: $0) }
                MainActor.assumeIsolated { onChange(programas) }
            }
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
            hosts: data["hosts"] as? [String] ?? []
        )
    }
}
