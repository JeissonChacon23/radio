// radio/Core/Audio/ListenerPresenceService.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ActiveListenerRecord: Identifiable, Hashable {
    let id: String       // docId ("{uid}_{deviceID}")
    let uid: String
    let name: String?
    let email: String?
    let lastSeen: Date
    let platform: String
    let profileType: String?
    let careerId: String?
    let departmentId: String?
}

struct RegisteredUserRecord: Identifiable, Hashable {
    let id: String       // uid
    let name: String
    let email: String
    let profileType: ProfileType
    let careerId: String?
    let departmentId: String?

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !email.isEmpty, let atIndex = email.firstIndex(of: "@") {
            let local = String(email[..<atIndex])
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !local.isEmpty {
                return local.capitalized
            }
        }
        return "Usuario \(id.prefix(6))"
    }
}

struct ListenerPresenceService {
    /// Un oyente se considera activo si renovó su presencia dentro de esta ventana (150 s).
    static let activeWindow: TimeInterval = 150

    private var collection: CollectionReference {
        Firestore.firestore().collection("listeners")
    }

    /// ID estable por instalación, para que cada dispositivo cuente por separado.
    private static let deviceID: String = {
        let key = "listenerDeviceID"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    private func documentID(for uid: String) -> String {
        "\(uid)_\(Self.deviceID)"
    }

    /// Registra o renueva la presencia de este dispositivo en la app iOS.
    func join() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        let uid = currentUser.uid
        let docRef = collection.document(documentID(for: uid))
        let basePayload: [String: Any] = [
            "lastSeen": FieldValue.serverTimestamp(),
            "expireAt": Timestamp(date: Date().addingTimeInterval(600)),
            "platform": "ios"
        ]

        let defaults = UserDefaults.standard
        var enrichedPayload = basePayload
        enrichedPayload["uid"] = uid
        if let savedName = defaults.string(forKey: "profile.name.\(uid)") ?? currentUser.displayName,
           !savedName.isEmpty {
            enrichedPayload["name"] = savedName
        }
        if let email = currentUser.email, !email.isEmpty {
            enrichedPayload["email"] = email
        }
        if let profileType = defaults.string(forKey: "profile.profileType.\(uid)") {
            enrichedPayload["profileType"] = profileType
        }
        if let careerId = defaults.string(forKey: "profile.careerId.\(uid)"), !careerId.isEmpty {
            enrichedPayload["careerId"] = careerId
        }
        if let departmentId = defaults.string(forKey: "profile.departmentId.\(uid)"), !departmentId.isEmpty {
            enrichedPayload["departmentId"] = departmentId
        }

        do {
            try await docRef.setData(enrichedPayload)
        } catch {
            do {
                try await docRef.setData(basePayload)
            } catch {
                print("Error registrando presencia: \(error)")
            }
        }
    }

    /// Elimina la presencia de este dispositivo.
    func leave() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await collection.document(documentID(for: uid)).delete()
        } catch {
            print("Error eliminando presencia: \(error)")
        }
    }

    /// RF05 / HU-03: Cantidad de usuarios de la app escuchando ahora mismo (excluye web y FM).
    func currentCount() async throws -> Int {
        let cutoff = Timestamp(date: Date().addingTimeInterval(-Self.activeWindow))
        let query = collection.whereField("lastSeen", isGreaterThan: cutoff)
        do {
            let docs = try await query.getDocuments()
            let activeRecords = docs.documents.compactMap { Self.parseListener(doc: $0, cutoffDate: cutoff.dateValue()) }
            return Set(activeRecords.map(\.uid)).count
        } catch {
            let snapshot = try await query.count.getAggregation(source: .server)
            return snapshot.count.intValue
        }
    }

    /// Suscripción en tiempo real a la colección `listeners` para actualizar Inicio al instante (RF05 / HU-03).
    func observeActiveListeners(
        onChange: @escaping @MainActor ([ActiveListenerRecord]) -> Void
    ) -> ListenerRegistration {
        collection.addSnapshotListener { snapshot, error in
            guard error == nil, let snapshot else { return }
            let cutoffDate = Date().addingTimeInterval(-Self.activeWindow)
            let records = snapshot.documents.compactMap { Self.parseListener(doc: $0, cutoffDate: cutoffDate) }
            MainActor.assumeIsolated {
                onChange(records)
            }
        }
    }

    nonisolated static func parseListener(doc: QueryDocumentSnapshot, cutoffDate: Date) -> ActiveListenerRecord? {
        let data = doc.data()
        let platform = (data["platform"] as? String ?? "ios").lowercased()
        // RF05 / HU-03: Only mobile app users count (never web or FM).
        guard platform == "ios" || platform == "app" else { return nil }
        guard let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue(),
              lastSeen > cutoffDate else { return nil }

        let explicitUid = (data["uid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid: String = {
            if let explicitUid, !explicitUid.isEmpty { return explicitUid }
            let docId = doc.documentID
            if let idx = docId.lastIndex(of: "_"), idx > docId.startIndex {
                return String(docId[..<idx])
            }
            return docId
        }()

        var careerId = data["careerId"] as? String
        var departmentId = data["departmentId"] as? String
        if let c = careerId, c.hasPrefix("dept:") {
            departmentId = departmentId ?? c
            careerId = nil
        }

        return ActiveListenerRecord(
            id: doc.documentID,
            uid: uid,
            name: (data["name"] as? String) ?? (data["displayName"] as? String),
            email: data["email"] as? String,
            lastSeen: lastSeen,
            platform: platform,
            profileType: data["profileType"] as? String,
            careerId: careerId,
            departmentId: departmentId
        )
    }
}
