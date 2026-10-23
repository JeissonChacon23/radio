// radio/Features/Programacion/ViewModel/ProgramacionViewModel.swift

//
//  ProgramacionViewModel.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

// radio/Features/Programacion/ViewModel/ProgramacionViewModel.swift

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class ProgramacionViewModel {
    var selectedDay: Int = ProgramacionViewModel.todayISO()

    private(set) var programas: [Programa] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let service = ProgramacionService()
    private var listener: ListenerRegistration?

    var programasDelDia: [Programa] {
        programas
            .filter { $0.days.contains(selectedDay) }
            .sorted { $0.startMinutes < $1.startMinutes }
    }

    func start() {
        guard listener == nil else { return }
        errorMessage = nil
        if programas.isEmpty { isLoading = true }

        listener = service.observeProgramas(
            onChange: { [weak self] programas in
                self?.programas = programas
                self?.errorMessage = nil
                self?.isLoading = false
            },
            onError: { [weak self] _ in
                self?.isLoading = false
                self?.errorMessage = "No se pudo cargar la programación."
            }
        )
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func isOnAir(_ programa: Programa, now: Date = .now) -> Bool {
        guard selectedDay == Self.todayISO() else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let current = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return current >= programa.startMinutes
            && current < programa.startMinutes + programa.durationMinutes
    }

    /// Fecha que corresponde a un día ISO (1 = lunes ... 7 = domingo) dentro de la semana actual.
    func date(forISODay day: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let offset = day - Self.todayISO()
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    /// Calendar uses 1 = Sunday ... 7 = Saturday; the web saves ISO days (1 = Monday ... 7 = Sunday).
    static func todayISO() -> Int {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return (weekday + 5) % 7 + 1
    }
}
