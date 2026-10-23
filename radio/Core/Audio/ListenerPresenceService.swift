// radio/Core/Audio/ListenerPresenceService.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ListenerPresenceService {
    /// Un oyente se considera activo si renovó su presencia dentro de esta ventana.
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

    /// Registra o renueva la presencia de este dispositivo.
    func join() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await collection.document(documentID(for: uid)).setData([
                "lastSeen": FieldValue.serverTimestamp(),
                "expireAt": Timestamp(date: Date().addingTimeInterval(600)),
                "platform": "ios"
            ])
        } catch {
            print("Error registrando presencia: \(error)")
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

    /// Cantidad de oyentes activos ahora mismo.
    func currentCount() async throws -> Int {
        let cutoff = Timestamp(date: Date().addingTimeInterval(-Self.activeWindow))
        let query = collection.whereField("lastSeen", isGreaterThan: cutoff)
        let snapshot = try await query.count.getAggregation(source: .server)
        return snapshot.count.intValue
    }
}
