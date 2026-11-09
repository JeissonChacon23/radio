// radio/Features/Calendario/Model/CalendarioModels.swift

import Foundation

struct Evento: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let specialGuest: String
    let startTime: String
    let endTime: String
    let link: URL?
    let audience: [String]
    let date: Date
    let endDate: Date?

    init(
        id: String,
        title: String,
        description: String,
        specialGuest: String = "",
        startTime: String = "",
        endTime: String = "",
        link: URL?,
        audience: [String],
        date: Date,
        endDate: Date?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.specialGuest = specialGuest
        self.startTime = startTime
        self.endTime = endTime
        self.link = link
        self.audience = audience
        self.date = date
        self.endDate = endDate
    }
}

extension Evento {
    var timeRangeText: String? {
        let startClock = Self.formattedTime(startTime, fallbackDate: date)
        let endClock = Self.formattedTime(endTime, fallbackDate: nil)
        if startClock.isEmpty && endClock.isEmpty {
            return nil
        }
        if !startClock.isEmpty && !endClock.isEmpty {
            return "\(startClock) – \(endClock)"
        }
        return startClock.isEmpty ? endClock : startClock
    }

    var dateRangeText: String {
        let startDay = date.formatted(date: .long, time: .omitted)
        let startClock = Self.formattedTime(startTime, fallbackDate: date)
        let startPart = startClock.isEmpty ? startDay : "\(startDay) · \(startClock)"

        guard let endDate else {
            if !endTime.isEmpty {
                return "\(startPart) – \(Self.formattedTime(endTime, fallbackDate: nil))"
            }
            return startPart
        }

        let sameDay = Calendar.current.isDate(endDate, inSameDayAs: date)
        let endClock = Self.formattedTime(endTime, fallbackDate: nil)
        if sameDay {
            return endClock.isEmpty ? startPart : "\(startPart) – \(endClock)"
        }
        let endDay = endDate.formatted(date: .long, time: .omitted)
        return endClock.isEmpty ? "\(startPart) – \(endDay)" : "\(startPart) – \(endDay) · \(endClock)"
    }

    static func formattedTime(_ hhmm: String, fallbackDate: Date?) -> String {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            let date = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: .now) ?? .now
            return date.formatted(date: .omitted, time: .shortened)
        }
        if let fallbackDate {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: fallbackDate)
            // Legacy events without explicit time were saved at 12:00:00
            if comps.hour == 12 && comps.minute == 0 {
                return ""
            }
            return fallbackDate.formatted(date: .omitted, time: .shortened)
        }
        return ""
    }
}
