// radio/Core/Session/SessionStore.swift

//
//  SessionStore.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

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

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        userId = result.user.uid
        self.email = result.user.email
        state = .needsProfile
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func editProfile() {
        state = .needsProfile
    }

    func saveProfile(type: ProfileType, careerId: String?, departmentId: String? = nil) async throws {
        guard let uid = userId ?? Auth.auth().currentUser?.uid else { throw SessionError.noUser }
        userId = uid

        let resolvedCareerId = type.requiresProgram ? careerId : nil
        let resolvedDepartmentId: String? = {
            if let departmentId, !departmentId.isEmpty { return departmentId }
            if let resolvedCareerId {
                let campus = resolvedCareerId.contains("ocana") ? "ocana" : "cucuta"
                let dept = Career.defaultDepartment(for: resolvedCareerId, faculty: "", campus: campus)
                return Career.makeDepartmentId(department: dept, campus: campus)
            }
            return nil
        }()

        var data: [String: Any] = [
            "profileType": type.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let resolvedCareerId {
            data["careerId"] = resolvedCareerId
        }
        if let resolvedDepartmentId {
            data["departmentId"] = resolvedDepartmentId
        }

        let docRef = db.collection("users").document(uid)
        do {
            try await docRef.setData(data)
        } catch {
            // Fallback in case deployed Firestore Security Rules only allow the original schema
            // (profileType, careerId only for estudiante, createdAt, updatedAt).
            var legacyData: [String: Any] = [
                "profileType": type.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if type == .estudiante, let resolvedCareerId {
                legacyData["careerId"] = resolvedCareerId
            }
            try await docRef.setData(legacyData)
        }

        Self.saveLocalMetadata(uid: uid, careerId: resolvedCareerId, departmentId: resolvedDepartmentId)

        state = .ready(
            UserProfile(
                profileType: type,
                careerId: resolvedCareerId,
                departmentId: resolvedDepartmentId
            )
        )
    }

    func signOut() {
        try? Auth.auth().signOut()
        clearUser()
        state = .signedOut
    }

    /// Not used by any screen right now. Re-authenticates first, because Firebase only
    /// deletes accounts with a recent sign-in.
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
        do {
            let snapshot = try await db.collection("users").document(user.uid).getDocument()
            if let data = snapshot.data(), let profile = Self.profile(from: data, uid: user.uid) {
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
    }

    private static func saveLocalMetadata(uid: String, careerId: String?, departmentId: String?) {
        let defaults = UserDefaults.standard
        defaults.set(careerId, forKey: "profile.careerId.\(uid)")
        defaults.set(departmentId, forKey: "profile.departmentId.\(uid)")
    }

    private static func profile(from data: [String: Any], uid: String) -> UserProfile? {
        guard let raw = data["profileType"] as? String,
              let type = ProfileType(rawValue: raw) else { return nil }

        let defaults = UserDefaults.standard
        let careerId = (data["careerId"] as? String) ?? defaults.string(forKey: "profile.careerId.\(uid)")
        var departmentId = (data["departmentId"] as? String) ?? defaults.string(forKey: "profile.departmentId.\(uid)")

        if departmentId == nil, let careerId {
            let campus = careerId.contains("ocana") ? "ocana" : "cucuta"
            let dept = Career.defaultDepartment(for: careerId, faculty: "", campus: campus)
            departmentId = Career.makeDepartmentId(department: dept, campus: campus)
        }

        // I1: If an egresado or estudiante account was created before without a program, or a docente without department, prompt to complete profile.
        if type.requiresProgram && (careerId == nil || careerId?.isEmpty == true) {
            return nil
        }
        if type.requiresDepartment && (departmentId == nil || departmentId?.isEmpty == true) {
            return nil
        }

        return UserProfile(profileType: type, careerId: careerId, departmentId: departmentId)
    }
}
