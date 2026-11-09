// radio/Features/Registro/ViewModel/RegistroViewModel.swift

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class RegistroViewModel {
    var profileType: ProfileType?
    var selectedCareerId: String?
    var selectedDepartmentId: String?
    var errorMessage: String?

    private(set) var careers: [Career] = []
    private(set) var isLoadingCareers = false
    private(set) var isSaving = false

    private var db: Firestore { Firestore.firestore() }

    var selectedCareer: Career? { careers.first { $0.id == selectedCareerId } }

    var departments: [DepartmentOption] {
        var seen = Set<String>()
        var result: [DepartmentOption] = []
        for c in careers {
            if seen.insert(c.departmentId).inserted {
                result.append(
                    DepartmentOption(
                        id: c.departmentId,
                        name: c.department,
                        faculty: c.faculty,
                        campus: c.campus
                    )
                )
            }
        }
        return result
    }

    var selectedDepartment: DepartmentOption? {
        departments.first { $0.id == selectedDepartmentId }
    }

    var canSubmit: Bool {
        guard let profileType else { return false }
        if profileType.requiresProgram {
            return selectedCareerId != nil
        }
        if profileType.requiresDepartment {
            return selectedDepartmentId != nil
        }
        return true
    }

    func select(_ type: ProfileType) {
        profileType = type
        if !type.requiresProgram {
            selectedCareerId = nil
        }
        if !type.requiresDepartment {
            selectedDepartmentId = nil
        }
    }

    func loadCareers() async {
        isLoadingCareers = true
        errorMessage = nil
        defer { isLoadingCareers = false }
        do {
            let snapshot = try await db.collection("careers").getDocuments()
            careers = snapshot.documents
                .compactMap { doc -> (career: Career, order: Int)? in
                    let data = doc.data()
                    guard (data["active"] as? Bool) ?? true,
                          let name = data["name"] as? String else { return nil }
                    let campus = data["campus"] as? String ?? "cucuta"
                    let faculty = data["faculty"] as? String ?? "Otras facultades"
                    let department = data["department"] as? String
                    let departmentId = data["departmentId"] as? String
                    let level = data["level"] as? String ?? "pregrado"
                    let career = Career(
                        id: doc.documentID,
                        name: name,
                        faculty: faculty,
                        department: department,
                        departmentId: departmentId,
                        level: level,
                        campus: campus,
                        modality: data["modality"] as? String ?? "presencial"
                    )
                    return (career, data["order"] as? Int ?? 0)
                }
                .sorted { ($0.order, $0.career.name) < ($1.order, $1.career.name) }
                .map(\.career)
        } catch {
            print("RegistroViewModel.loadCareers failed:", error)
            errorMessage = "No se pudo cargar la estructura académica."
        }
    }

    func submit(using session: SessionStore) async {
        guard let profileType, canSubmit else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let deptId: String? = {
                if profileType.requiresDepartment { return selectedDepartmentId }
                if profileType.requiresProgram { return selectedCareer?.departmentId }
                return nil
            }()
            try await session.saveProfile(
                type: profileType,
                careerId: profileType.requiresProgram ? selectedCareerId : nil,
                departmentId: deptId
            )
        } catch {
            print("RegistroViewModel.submit failed:", error)
            errorMessage = "No se pudo guardar tu perfil. Inténtalo de nuevo."
        }
    }
}
