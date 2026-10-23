// radio/Features/Inicio/ViewModel/ListenerCountViewModel.swift

import Foundation
import Observation

@MainActor
@Observable
final class ListenerCountViewModel {
    private(set) var count: Int?

    private let service = ListenerPresenceService()

    /// Consulta el conteo cada 30 s. Se cancela solo cuando la vista desaparece (.task).
    func run() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    func refresh() async {
        do {
            count = try await service.currentCount()
        } catch {
            print("Error obteniendo oyentes: \(error)")
        }
    }
}
