// radio/Features/Registro/ViewModel/RegistroViewModel.swift

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class RegistroViewModel {
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = "" {
        didSet {
            let digits = String(phone.filter(\.isNumber).prefix(15))
            if digits != phone { phone = digits }
        }
    }
    var studentCode: String = "" {
        didSet {
            let digitsOnly = studentCode.filter(\.isNumber)
            if digitsOnly != studentCode {
                studentCode = digitsOnly
                return
            }
            syncCareerFromStudentCode()
        }
    }
    var profileType: ProfileType?
    var selectedCareerId: String?
    var selectedDepartmentId: String?
    var errorMessage: String?

    private(set) var careers: [Career] = []
    private(set) var isLoadingCareers = false
    private(set) var isSaving = false

    private var db: Firestore { Firestore.firestore() }

    var selectedCareer: Career? { careers.first { $0.id == selectedCareerId } }

    /// Career automatically detected from the first 3 digits of `studentCode` (e.g., "115" -> Ingeniería de Sistemas).
    var detectedCareerFromCode: Career? {
        Career.findCareer(forStudentCode: studentCode, in: careers)
    }

    var studentCodePrefix: String {
        let digits = studentCode.filter(\.isNumber)
        return digits.count >= 3 ? String(digits.prefix(3)) : digits
    }

    var studentCodeValidationMessage: String? {
        guard profileType == .estudiante else { return nil }
        let count = studentCode.count
        if count == 0 {
            return "Ingresa tu código estudiantil de 7 dígitos (ej. 1151594)."
        }
        if count < 7 {
            return "El código estudiantil debe tener exactamente 7 dígitos (faltan \(7 - count) dígitos)."
        }
        if count > 7 {
            return "El código estudiantil debe tener exactamente 7 dígitos (tiene \(count) dígitos, sobran \(count - 7))."
        }
        if detectedCareerFromCode == nil {
            return "No existe una carrera registrada con el código \(studentCodePrefix). Verifica los primeros 3 dígitos."
        }
        return nil
    }

    var isStudentCodeValid: Bool {
        studentCode.count == 7 && detectedCareerFromCode != nil
    }

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

    var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedFullName: String {
        [trimmedFirstName, trimmedLastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var trimmedPhone: String {
        phone.filter(\.isNumber)
    }

    var canSubmit: Bool {
        guard !trimmedFirstName.isEmpty,
              !trimmedLastName.isEmpty,
              trimmedPhone.count >= 7,
              let profileType else { return false }
        switch profileType {
        case .estudiante:
            return isStudentCodeValid && selectedCareer != nil
        case .egresado:
            return selectedCareerId != nil
        case .docente:
            return selectedDepartmentId != nil
        case .administrativo, .invitado, .externo:
            return true
        }
    }

    func prefill(from session: SessionStore) {
        if firstName.isEmpty && lastName.isEmpty {
            let f = session.profile?.firstName ?? session.userFirstName ?? ""
            let l = session.profile?.lastName ?? session.userLastName ?? ""
            if !f.isEmpty || !l.isEmpty {
                firstName = f
                lastName = l
            } else if let full = session.profile?.name ?? session.userName, !full.isEmpty {
                let parts = full.split(whereSeparator: \.isWhitespace).map(String.init)
                if parts.count > 1 {
                    let mid = (parts.count + 1) / 2
                    firstName = parts[..<mid].joined(separator: " ")
                    lastName = parts[mid...].joined(separator: " ")
                } else {
                    firstName = full
                }
            }
        }
        if phone.isEmpty {
            phone = session.profile?.phone ?? session.userPhone ?? ""
        }
        if profileType == nil, let existingProfile = session.profile {
            profileType = existingProfile.profileType
            selectedCareerId = existingProfile.careerId
            selectedDepartmentId = existingProfile.departmentId
            if let sc = existingProfile.studentCode, !sc.isEmpty {
                studentCode = sc
            }
        }
    }

    func select(_ type: ProfileType) {
        profileType = type
        if type == .estudiante {
            syncCareerFromStudentCode()
        } else if !type.requiresProgram {
            selectedCareerId = nil
        }
        if !type.requiresDepartment {
            selectedDepartmentId = nil
        }
    }

    private func syncCareerFromStudentCode() {
        guard profileType == .estudiante else { return }
        if let matched = detectedCareerFromCode {
            selectedCareerId = matched.id
        } else {
            selectedCareerId = nil
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
                    let code = data["code"] as? String
                    let alternateCodes = data["alternateCodes"] as? [String] ?? []
                    let career = Career(
                        id: doc.documentID,
                        code: code,
                        alternateCodes: alternateCodes,
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

            if profileType == .estudiante {
                syncCareerFromStudentCode()
            }
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
            let careerToSave = profileType == .estudiante ? (detectedCareerFromCode ?? selectedCareer) : selectedCareer
            let deptId: String? = {
                if profileType.requiresDepartment { return selectedDepartmentId }
                if profileType.requiresProgram { return careerToSave?.departmentId }
                return nil
            }()
            try await session.saveProfile(
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                name: trimmedFullName,
                phone: trimmedPhone,
                studentCode: profileType == .estudiante ? studentCode : nil,
                type: profileType,
                career: profileType.requiresProgram ? careerToSave : nil,
                careerId: profileType.requiresProgram ? careerToSave?.id : nil,
                departmentOption: profileType.requiresDepartment ? selectedDepartment : nil,
                departmentId: deptId
            )
        } catch {
            print("RegistroViewModel.submit failed:", error)
            errorMessage = "No se pudo guardar tu perfil. Inténtalo de nuevo."
        }
    }
}
