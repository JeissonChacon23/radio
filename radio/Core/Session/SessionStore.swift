// radio/Core/Session/SessionStore.swift

//
//  SessionStore.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

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

    func saveProfile(type: ProfileType, careerId: String?) async throws {
        guard let userId else { throw SessionError.noUser }

        var data: [String: Any] = [
            "profileType": type.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if type == .estudiante, let careerId {
            data["careerId"] = careerId
        }

        try await db.collection("users").document(userId).setData(data)
        state = .ready(UserProfile(profileType: type, careerId: type == .estudiante ? careerId : nil))
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
            if let data = snapshot.data(), let profile = Self.profile(from: data) {
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

    private static func profile(from data: [String: Any]) -> UserProfile? {
        guard let raw = data["profileType"] as? String,
              let type = ProfileType(rawValue: raw) else { return nil }
        return UserProfile(profileType: type, careerId: data["careerId"] as? String)
    }
}
