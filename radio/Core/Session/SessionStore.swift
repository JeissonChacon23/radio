// radio/Core/Session/SessionStore.swift

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

enum SessionError: Error {
    case noUser
}

@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case loading
        case signedOut
        case needsProfile
        case ready(UserProfile)
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var userId: String?
    private(set) var email: String?
    private(set) var userFirstName: String?
    private(set) var userLastName: String?
    private(set) var userName: String?
    private(set) var userPhone: String?

    // Computed on purpose: Firestore must not be touched before FirebaseApp.configure().
    private var db: Firestore { Firestore.firestore() }

    var profile: UserProfile? {
        if case .ready(let profile) = state { return profile }
        return nil
    }

    init() {}

    #if DEBUG
    /// Only for SwiftUI previews: starts in a given state without touching Firebase.
    init(previewState: State, email: String? = "estudiante@ufps.edu.co") {
        self.state = previewState
        self.email = email
        self.userFirstName = "Estudiante"
        self.userLastName = "UFPS"
        self.userName = "Estudiante UFPS"
        self.userPhone = "3001234567"
    }
    #endif

    /// Runs at launch: restores the saved session, if there is one.
    func start() async {
        state = .loading
        guard let user = Auth.auth().currentUser else {
            clearUser()
            state = .signedOut
            return
        }
        await load(user: user)
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await load(user: result.user)
    }

    func signUp(
        firstName: String = "",
        lastName: String = "",
        phone: String = "",
        email: String,
        password: String
    ) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid
        userId = uid
        self.email = result.user.email ?? email

        let cleanFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.filter(\.isNumber)
        let cleanFull = [cleanFirst, cleanLast].filter { !$0.isEmpty }.joined(separator: " ")

        if !cleanFirst.isEmpty {
            self.userFirstName = cleanFirst
            UserDefaults.standard.set(cleanFirst, forKey: "profile.firstName.\(uid)")
        }
        if !cleanLast.isEmpty {
            self.userLastName = cleanLast
            UserDefaults.standard.set(cleanLast, forKey: "profile.lastName.\(uid)")
        }
        if !cleanPhone.isEmpty {
            self.userPhone = cleanPhone
            UserDefaults.standard.set(cleanPhone, forKey: "profile.phone.\(uid)")
        }
        if !cleanFull.isEmpty {
            self.userName = cleanFull
            UserDefaults.standard.set(cleanFull, forKey: "profile.name.\(uid)")
            let changeReq = result.user.createProfileChangeRequest()
            changeReq.displayName = cleanFull
            try? await changeReq.commitChanges()
        }

        state = .needsProfile
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw SessionError.noUser
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
        try await user.updatePassword(to: newPassword)
    }

    func editProfile() {
        state = .needsProfile
    }

    func saveProfile(
        firstName: String = "",
        lastName: String = "",
        name: String = "",
        phone: String? = nil,
        studentCode: String? = nil,
        type: ProfileType,
        career: Career? = nil,
        careerId: String? = nil,
        departmentOption: DepartmentOption? = nil,
        departmentId: String? = nil
    ) async throws {
        guard let uid = userId ?? Auth.auth().currentUser?.uid else { throw SessionError.noUser }
        userId = uid

        let currentUser = Auth.auth().currentUser
        let resolvedEmail = (email ?? currentUser?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedParts = [cleanFirst, cleanLast].filter { !$0.isEmpty }.joined(separator: " ")

        let resolvedName: String = {
            if !combinedParts.isEmpty { return combinedParts }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
            if let existing = userName, !existing.isEmpty { return existing }
            if let authName = currentUser?.displayName, !authName.isEmpty { return authName }
            if let saved = UserDefaults.standard.string(forKey: "profile.name.\(uid)"), !saved.isEmpty {
                return saved
            }
            return Self.deriveNameFromEmail(resolvedEmail)
        }()

        let resolvedPhone: String? = {
            if let raw = phone {
                let digits = raw.filter(\.isNumber)
                if !digits.isEmpty { return digits }
            }
            if let existingPhone = userPhone, !existingPhone.isEmpty { return existingPhone }
            if let savedPhone = UserDefaults.standard.string(forKey: "profile.phone.\(uid)"), !savedPhone.isEmpty {
                return savedPhone
            }
            return nil
        }()

        if !resolvedName.isEmpty, currentUser?.displayName != resolvedName {
            let req = currentUser?.createProfileChangeRequest()
            req?.displayName = resolvedName
            try? await req?.commitChanges()
        }
        self.userFirstName = cleanFirst
        self.userLastName = cleanLast
        self.userName = resolvedName
        self.userPhone = resolvedPhone

        let cleanStudentCode: String? = {
            guard type == .estudiante, let raw = studentCode else { return nil }
            let digits = raw.filter(\.isNumber)
            return digits.count == 7 ? digits : nil
        }()

        let resolvedProgramCode: String? = {
            if let cCode = career?.code, !cCode.isEmpty { return cCode }
            if let code = cleanStudentCode, code.count >= 3 {
                return String(code.prefix(3))
            }
            if let cid = career?.id ?? careerId {
                let def = Career.defaultCode(for: cid)
                return def.isEmpty ? nil : def
            }
            return nil
        }()

        let resolvedCareerId = type.requiresProgram ? (career?.id ?? careerId) : nil
        let resolvedCareerName = type.requiresProgram ? career?.name : nil
        let resolvedLevel = type.requiresProgram ? career?.level : nil
        let resolvedModality = type.requiresProgram ? career?.modality : nil

        let resolvedDepartmentId: String? = {
            if type.requiresProgram {
                if let cDeptId = career?.departmentId, !cDeptId.isEmpty { return cDeptId }
                if let departmentId, !departmentId.isEmpty { return departmentId }
                if let resolvedCareerId {
                    let campus = resolvedCareerId.contains("ocana") ? "ocana" : "cucuta"
                    let dept = Career.defaultDepartment(for: resolvedCareerId, faculty: "", campus: campus)
                    return Career.makeDepartmentId(department: dept, campus: campus)
                }
                return nil
            }
            if type.requiresDepartment {
                return departmentOption?.id ?? departmentId
            }
            return nil
        }()

        let resolvedDepartmentName: String? = {
            if type.requiresProgram {
                if let cDept = career?.department, !cDept.isEmpty { return cDept }
                if let resolvedCareerId {
                    let campus = resolvedCareerId.contains("ocana") ? "ocana" : "cucuta"
                    return Career.defaultDepartment(for: resolvedCareerId, faculty: "", campus: campus)
                }
                return nil
            }
            if type.requiresDepartment {
                return departmentOption?.name
            }
            return nil
        }()

        let resolvedFaculty: String? = {
            if type.requiresProgram { return career?.faculty }
            if type.requiresDepartment { return departmentOption?.faculty }
            return nil
        }()

        let resolvedCampus: String? = {
            if type.requiresProgram { return career?.campus }
            if type.requiresDepartment { return departmentOption?.campus }
            return nil
        }()

        var data: [String: Any] = [
            "firstName": cleanFirst,
            "lastName": cleanLast,
            "name": resolvedName,
            "email": resolvedEmail,
            "profileType": type.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let resolvedPhone {
            data["phone"] = resolvedPhone
        } else {
            data["phone"] = FieldValue.delete()
        }
        if let cleanStudentCode {
            data["studentCode"] = cleanStudentCode
        } else {
            data["studentCode"] = FieldValue.delete()
        }
        if let resolvedProgramCode {
            data["programCode"] = resolvedProgramCode
        } else {
            data["programCode"] = FieldValue.delete()
        }
        if let resolvedCareerId {
            data["careerId"] = resolvedCareerId
        } else {
            data["careerId"] = FieldValue.delete()
        }
        if let resolvedCareerName {
            data["careerName"] = resolvedCareerName
        } else {
            data["careerName"] = FieldValue.delete()
        }
        if let resolvedDepartmentId {
            data["departmentId"] = resolvedDepartmentId
        } else {
            data["departmentId"] = FieldValue.delete()
        }
        if let resolvedDepartmentName {
            data["department"] = resolvedDepartmentName
        } else {
            data["department"] = FieldValue.delete()
        }
        if let resolvedFaculty {
            data["faculty"] = resolvedFaculty
        } else {
            data["faculty"] = FieldValue.delete()
        }
        if let resolvedCampus {
            data["campus"] = resolvedCampus
        } else {
            data["campus"] = FieldValue.delete()
        }
        if let resolvedLevel {
            data["level"] = resolvedLevel
        } else {
            data["level"] = FieldValue.delete()
        }
        if let resolvedModality {
            data["modality"] = resolvedModality
        } else {
            data["modality"] = FieldValue.delete()
        }

        let docRef = db.collection("users").document(uid)
        try await docRef.setData(data, merge: true)

        Self.saveLocalMetadata(
            uid: uid,
            firstName: cleanFirst,
            lastName: cleanLast,
            name: resolvedName,
            phone: resolvedPhone,
            studentCode: cleanStudentCode,
            profileType: type.rawValue,
            careerId: resolvedCareerId,
            departmentId: resolvedDepartmentId
        )

        state = .ready(
            UserProfile(
                firstName: cleanFirst,
                lastName: cleanLast,
                name: resolvedName,
                phone: resolvedPhone,
                studentCode: cleanStudentCode,
                programCode: resolvedProgramCode,
                profileType: type,
                careerId: resolvedCareerId,
                careerName: resolvedCareerName,
                departmentId: resolvedDepartmentId,
                department: resolvedDepartmentName,
                faculty: resolvedFaculty
            )
        )
    }

    func signOut() {
        try? Auth.auth().signOut()
        clearUser()
        state = .signedOut
    }

    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw SessionError.noUser
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
        try await db.collection("users").document(user.uid).delete()
        try await user.delete()
        clearUser()
        state = .signedOut
    }

    private func load(user: User) async {
        userId = user.uid
        email = user.email
        userFirstName = UserDefaults.standard.string(forKey: "profile.firstName.\(user.uid)")
        userLastName = UserDefaults.standard.string(forKey: "profile.lastName.\(user.uid)")
        userName = user.displayName ?? UserDefaults.standard.string(forKey: "profile.name.\(user.uid)")
        userPhone = UserDefaults.standard.string(forKey: "profile.phone.\(user.uid)")
        do {
            let docRef = db.collection("users").document(user.uid)
            let snapshot = try await docRef.getDocument()
            if let data = snapshot.data(),
               let profile = Self.profile(from: data, uid: user.uid, fallbackEmail: user.email, fallbackName: user.displayName) {
                self.userFirstName = profile.firstName
                self.userLastName = profile.lastName
                self.userName = profile.name
                self.userPhone = profile.phone
                Self.saveLocalMetadata(
                    uid: user.uid,
                    firstName: profile.firstName,
                    lastName: profile.lastName,
                    name: profile.name,
                    phone: profile.phone,
                    studentCode: profile.studentCode,
                    profileType: profile.profileType.rawValue,
                    careerId: profile.careerId,
                    departmentId: profile.departmentId
                )

                var missingFields: [String: Any] = [:]
                if (data["email"] as? String ?? "").isEmpty, let userEmail = user.email, !userEmail.isEmpty {
                    missingFields["email"] = userEmail
                }
                if (data["name"] as? String ?? "").isEmpty, !profile.name.isEmpty {
                    missingFields["name"] = profile.name
                }
                if !missingFields.isEmpty {
                    try? await docRef.setData(missingFields, merge: true)
                }

                state = .ready(profile)
            } else {
                state = .needsProfile
            }
        } catch {
            print("SessionStore.load failed:", error)
            state = .failed("No se pudo cargar tu perfil. Revisa tu conexión e inténtalo de nuevo.")
        }
    }

    private func clearUser() {
        userId = nil
        email = nil
        userFirstName = nil
        userLastName = nil
        userName = nil
        userPhone = nil
    }

    private static func saveLocalMetadata(
        uid: String,
        firstName: String,
        lastName: String,
        name: String,
        phone: String?,
        studentCode: String?,
        profileType: String,
        careerId: String?,
        departmentId: String?
    ) {
        let defaults = UserDefaults.standard
        defaults.set(firstName, forKey: "profile.firstName.\(uid)")
        defaults.set(lastName, forKey: "profile.lastName.\(uid)")
        defaults.set(name, forKey: "profile.name.\(uid)")
        defaults.set(phone, forKey: "profile.phone.\(uid)")
        defaults.set(studentCode, forKey: "profile.studentCode.\(uid)")
        defaults.set(profileType, forKey: "profile.profileType.\(uid)")
        defaults.set(careerId, forKey: "profile.careerId.\(uid)")
        defaults.set(departmentId, forKey: "profile.departmentId.\(uid)")
    }

    private static func deriveNameFromEmail(_ email: String) -> String {
        guard let atIdx = email.firstIndex(of: "@") else { return "" }
        let local = String(email[..<atIdx])
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return local.isEmpty ? "" : local.capitalized
    }

    private static func profile(
        from data: [String: Any],
        uid: String,
        fallbackEmail: String?,
        fallbackName: String?
    ) -> UserProfile? {
        guard let raw = data["profileType"] as? String,
              let type = ProfileType.fromFirestore(raw) else { return nil }

        let defaults = UserDefaults.standard
        var rawCareer = (data["careerId"] as? String) ?? defaults.string(forKey: "profile.careerId.\(uid)")
        var departmentId = (data["departmentId"] as? String) ?? defaults.string(forKey: "profile.departmentId.\(uid)")
        let studentCode = (data["studentCode"] as? String) ?? defaults.string(forKey: "profile.studentCode.\(uid)")
        let phone = (data["phone"] as? String) ?? defaults.string(forKey: "profile.phone.\(uid)")

        if let rc = rawCareer, rc.hasPrefix("dept:") {
            departmentId = departmentId ?? rc
            rawCareer = nil
        }
        let careerId = rawCareer

        if departmentId == nil, let careerId {
            let campus = careerId.contains("ocana") ? "ocana" : "cucuta"
            let dept = Career.defaultDepartment(for: careerId, faculty: "", campus: campus)
            departmentId = Career.makeDepartmentId(department: dept, campus: campus)
        }

        if type.requiresProgram && (careerId == nil || careerId?.isEmpty == true) {
            return nil
        }
        if type.requiresDepartment && (departmentId == nil || departmentId?.isEmpty == true) {
            return nil
        }

        let storedFirst = (data["firstName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? defaults.string(forKey: "profile.firstName.\(uid)") ?? ""
        let storedLast = (data["lastName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? defaults.string(forKey: "profile.lastName.\(uid)") ?? ""
        let storedName = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedName: String = {
            let combined = [storedFirst, storedLast].filter { !$0.isEmpty }.joined(separator: " ")
            if !combined.isEmpty { return combined }
            if !storedName.isEmpty { return storedName }
            if let fn = fallbackName, !fn.isEmpty { return fn }
            if let localName = defaults.string(forKey: "profile.name.\(uid)"), !localName.isEmpty {
                return localName
            }
            return deriveNameFromEmail(fallbackEmail ?? (data["email"] as? String ?? ""))
        }()

        let programCode: String? = {
            if let pc = data["programCode"] as? String, !pc.isEmpty { return pc }
            if let sc = studentCode, sc.count >= 3 { return String(sc.prefix(3)) }
            if let cid = careerId {
                let def = Career.defaultCode(for: cid)
                return def.isEmpty ? nil : def
            }
            return nil
        }()

        return UserProfile(
            firstName: storedFirst,
            lastName: storedLast,
            name: resolvedName,
            phone: phone,
            studentCode: studentCode,
            programCode: programCode,
            profileType: type,
            careerId: careerId,
            careerName: data["careerName"] as? String,
            departmentId: departmentId,
            department: data["department"] as? String,
            faculty: data["faculty"] as? String
        )
    }
}
