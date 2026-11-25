// radio/Features/Calendario/ViewModel/CalendarioViewModel.swift

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class CalendarioViewModel {
    private static let starredStorageKey = "calendar.starredEventIds"

    private(set) var eventos: [Evento] = []
    private(set) var eventDays: Set<Date> = []
    private(set) var starredIds: Set<String> = CalendarioViewModel.loadStarredIds()
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    private(set) var displayedMonth: Date = CalendarioViewModel.startOfMonth(for: .now)

    @ObservationIgnored private let service = CalendarioService()
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var currentProfile: UserProfile?

    private var calendar: Calendar { .current }

    // MARK: - Escucha de Firestore

    func start(profile: UserProfile) {
        guard listener == nil || profile != currentProfile else { return }
        stop()
        currentProfile = profile
        errorMessage = nil
        if eventos.isEmpty { isLoading = true }

        listener = service.observeEventos(
            profile: profile,
            onChange: { [weak self] eventos in
                self?.apply(eventos)
            },
            onError: { [weak self] _ in
                self?.isLoading = false
                self?.errorMessage = "No se pudo cargar el calendario."
            }
        )
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    private func apply(_ nuevos: [Evento]) {
        eventos = nuevos.sorted { $0.date < $1.date }
        eventDays = computeEventDays(from: eventos)
        errorMessage = nil
        isLoading = false
    }

    /// Todos los días (a las 00:00) que tienen al menos un evento, incluyendo rangos.
    private func computeEventDays(from eventos: [Evento]) -> Set<Date> {
        var days = Set<Date>()
        for evento in eventos {
            let start = calendar.startOfDay(for: evento.date)
            let rawEnd = calendar.startOfDay(for: evento.endDate ?? evento.date)
            let end = max(start, rawEnd)

            var day = start
            var guardCount = 0
            while day <= end, guardCount < 366 {
                days.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                guardCount += 1
            }
        }
        return days
    }

    // MARK: - Consultas

    func hasEvents(on date: Date) -> Bool {
        eventDays.contains(calendar.startOfDay(for: date))
    }

    func eventos(on date: Date) -> [Evento] {
        let day = calendar.startOfDay(for: date)
        return eventos.filter { evento in
            let start = calendar.startOfDay(for: evento.date)
            let end = max(start, calendar.startOfDay(for: evento.endDate ?? evento.date))
            return day >= start && day <= end
        }
    }

    var selectedEventos: [Evento] { eventos(on: selectedDate) }

    /// Eventos que el usuario ha marcado como destacados, ordenados por fecha.
    var starredEventos: [Evento] {
        eventos.filter { starredIds.contains($0.id) }
    }

    func isStarred(_ evento: Evento) -> Bool {
        starredIds.contains(evento.id)
    }

    func toggleStar(_ evento: Evento) {
        if starredIds.contains(evento.id) {
            starredIds.remove(evento.id)
        } else {
            starredIds.insert(evento.id)
        }
        UserDefaults.standard.set(Array(starredIds), forKey: Self.starredStorageKey)
    }

    func jumpTo(_ evento: Evento) {
        let day = calendar.startOfDay(for: evento.date)
        selectedDate = day
        displayedMonth = Self.startOfMonth(for: day)
    }

    private static func loadStarredIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: starredStorageKey) ?? []
        return Set(array)
    }

    // MARK: - Navegación del calendario

    func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = Self.startOfMonth(for: newMonth)
    }

    func goToToday() {
        let today = calendar.startOfDay(for: .now)
        selectedDate = today
        displayedMonth = Self.startOfMonth(for: today)
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
