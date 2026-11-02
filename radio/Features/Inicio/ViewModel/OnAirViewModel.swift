//
//  OnAirViewModel.swift
//  radio
//
//  Created by Foster Chacon on 28/10/26.
//

// radio/Features/Inicio/ViewModel/OnAirViewModel.swift

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class OnAirViewModel {
    private(set) var programas: [Programa] = []

    @ObservationIgnored private let service = ProgramacionService()
    @ObservationIgnored private var listener: ListenerRegistration?

    init() {}

    #if DEBUG
    /// Only for SwiftUI previews.
    init(previewProgramas: [Programa]) {
        programas = previewProgramas
    }
    #endif

    func start() {
        guard listener == nil else { return }
        listener = service.observeProgramas(
            onChange: { [weak self] programas in
                self?.programas = programas
            },
            onError: { error in
                print("OnAirViewModel: could not load programs:", error)
            }
        )
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// If two programs overlap, the one that started last wins.
    func programaAlAire(at date: Date = .now) -> Programa? {
        programas
            .filter { $0.isOnAir(at: date) }
            .max { $0.startMinutes < $1.startMinutes }
    }
}
