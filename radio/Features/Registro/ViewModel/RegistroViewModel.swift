// radio/Features/Registro/ViewModel/RegistroViewModel.swift

//
//  RegistroViewModel.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class RegistroViewModel {
    var profileType: ProfileType?
    var selectedCareerId: String?
    var errorMessage: String?

    private(set) var careers: [Career] = []
    private(set) var isLoadingCareers = false
    private(set) var isSaving = false

    private var db: Firestore { Firestore.firestore() }

    var selectedCareer: Career? { careers.first { $0.id == selectedCareerId } }

    var canSubmit: Bool {
        guard let profileType else { return false }
        return profileType != .estudiante || selectedCareerId != nil
    }

    func select(_ type: ProfileType) {
        profileType = type
        if type != .estudiante { selectedCareerId = nil }
    }

    func loadCareers() async {
        isLoadingCareers = true
        defer { isLoadingCareers = false }
        do {
            // Filtered and sorted on the client, so no Firestore index is needed.
            let snapshot = try await db.collection("careers").getDocuments()
            careers = snapshot.documents
                .compactMap { doc -> (career: Career, order: Int)? in
                    let data = doc.data()
                    guard (data["active"] as? Bool) ?? true,
                          let name = data["name"] as? String else { return nil }
                    let career = Career(
                        id: doc.documentID,
                        name: name,
                        faculty: data["faculty"] as? String ?? "Otras carreras",
                        campus: data["campus"] as? String ?? "cucuta",
                        modality: data["modality"] as? String ?? "presencial"
                    )
                    return (career, data["order"] as? Int ?? 0)
                }
                .sorted { ($0.order, $0.career.name) < ($1.order, $1.career.name) }
                .map(\.career)
        } catch {
            print("RegistroViewModel.loadCareers failed:", error)
            errorMessage = "No se pudo cargar la lista de carreras."
        }
    }

    func submit(using session: SessionStore) async {
        guard let profileType, canSubmit else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await session.saveProfile(type: profileType, careerId: selectedCareerId)
        } catch {
            print("RegistroViewModel.submit failed:", error)
            errorMessage = "No se pudo guardar tu perfil. Inténtalo de nuevo."
        }
    }
}
