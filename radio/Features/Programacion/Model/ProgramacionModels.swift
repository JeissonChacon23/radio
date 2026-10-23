// radio/Features/Programacion/Model/ProgramacionModels.swift

//
//  ProgramacionModels.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//
import Foundation

struct Programa: Identifiable, Hashable {
    let id: String
    let name: String
    let days: [Int]          // ISO weekdays: 1 = Monday ... 7 = Sunday
    let startTime: String    // "HH:mm", Colombia local time
    let durationMinutes: Int
    let collective: String
    let hosts: [String]
}

extension Programa {
    var startMinutes: Int {
        let parts = startTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    var timeRangeText: String {
        "\(Self.timeText(minutes: startMinutes)) – \(Self.timeText(minutes: startMinutes + durationMinutes))"
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
