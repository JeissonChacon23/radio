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

    /// I3: Defense against overlapping schedules — only one program can be on air at a time.
    func programaAlAire(at date: Date = .now) -> Programa? {
        programas
            .filter { $0.isOnAir(at: date) }
            .max { a, b in
                if a.startMinutes != b.startMinutes {
                    return a.startMinutes < b.startMinutes
                }
                if a.durationMinutes != b.durationMinutes {
                    return a.durationMinutes > b.durationMinutes
                }
                return a.id < b.id
            }
    }

    /// Programs scheduled for today (in Colombia time), sorted chronologically.
    func programasDeHoy(at date: Date = .now) -> [Programa] {
        let now = RadioClock.now(date)
        return programas
            .filter { $0.days.contains(now.isoDay) }
            .sorted { ($0.startMinutes, $0.name) < ($1.startMinutes, $1.name) }
    }

    /// Programs of today that have already finished (or started before the current on-air program).
    func programasPasados(at date: Date = .now) -> [Programa] {
        let now = RadioClock.now(date)
        let alAire = programaAlAire(at: date)
        return programasDeHoy(at: date).filter { programa in
            guard programa.id != alAire?.id else { return false }
            if let alAire {
                return (programa.startMinutes, programa.name) < (alAire.startMinutes, alAire.name)
            }
            return programa.startMinutes + programa.durationMinutes <= now.minutes
        }
    }

    /// Programs of today that will air after the current time / current on-air program.
    func programasProximos(at date: Date = .now) -> [Programa] {
        let now = RadioClock.now(date)
        let alAire = programaAlAire(at: date)
        return programasDeHoy(at: date).filter { programa in
            guard programa.id != alAire?.id else { return false }
            if let alAire {
                return (programa.startMinutes, programa.name) >= (alAire.startMinutes, alAire.name)
            }
            return programa.startMinutes + programa.durationMinutes > now.minutes
        }
    }
}
