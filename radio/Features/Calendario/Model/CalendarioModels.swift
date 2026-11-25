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

    /// Formats time in 24-hour military format ("HH:mm", e.g. "08:00", "14:30").
    static func formattedTime(_ hhmm: String, fallbackDate: Date?) -> String {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            let h = min(max(parts[0], 0), 23)
            let m = min(max(parts[1], 0), 59)
            return String(format: "%02d:%02d", h, m)
        }
        if let fallbackDate {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: fallbackDate)
            let h = comps.hour ?? 0
            let m = comps.minute ?? 0
            // Legacy events without explicit time were saved at 12:00:00
            if h == 12 && m == 0 {
                return ""
            }
            return String(format: "%02d:%02d", h, m)
        }
        return ""
    }
}
