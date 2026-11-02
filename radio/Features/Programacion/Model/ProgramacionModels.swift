// radio/Features/Programacion/Model/ProgramacionModels.swift

import Foundation

struct Programa: Identifiable, Hashable {
    let id: String
    let name: String
    let days: [Int]          // ISO weekdays: 1 = Monday ... 7 = Sunday
    let startTime: String    // "HH:mm", Colombia local time
    let durationMinutes: Int
    let collective: String
    let hosts: [String]
    let artworkDriveId: String
}

extension Programa {
    var artworkId: String? { artworkDriveId.isEmpty ? nil : artworkDriveId }

    var startMinutes: Int {
        let parts = startTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    var timeRangeText: String {
        "\(Self.timeText(minutes: startMinutes)) – \(Self.timeText(minutes: startMinutes + durationMinutes))"
    }

    /// Uses Colombia time, because the schedule is the station's.
    func isOnAir(at date: Date = .now) -> Bool {
        let now = RadioClock.now(date)
        let end = startMinutes + durationMinutes

        if days.contains(now.isoDay), now.minutes >= startMinutes, now.minutes < end {
            return true
        }
        // A program that crosses midnight is still on air after 00:00 of the next day.
        let previousDay = now.isoDay == 1 ? 7 : now.isoDay - 1
        return days.contains(previousDay) && end > 24 * 60 && now.minutes + 24 * 60 < end
    }

    private static func timeText(minutes: Int) -> String {
        let normalized = minutes % (24 * 60)
        let date = Calendar.current.date(
            bySettingHour: normalized / 60,
            minute: normalized % 60,
            second: 0,
            of: .now
        ) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct DiaSemana: Identifiable {
    let id: Int // ISO weekday
    let short: String
    let full: String

    static let all: [DiaSemana] = [
        DiaSemana(id: 1, short: "Lun", full: "Lunes"),
        DiaSemana(id: 2, short: "Mar", full: "Martes"),
        DiaSemana(id: 3, short: "Mié", full: "Miércoles"),
        DiaSemana(id: 4, short: "Jue", full: "Jueves"),
        DiaSemana(id: 5, short: "Vie", full: "Viernes"),
        DiaSemana(id: 6, short: "Sáb", full: "Sábado"),
        DiaSemana(id: 7, short: "Dom", full: "Domingo")
    ]
}
