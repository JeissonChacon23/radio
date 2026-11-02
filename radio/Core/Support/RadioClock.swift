//
//  RadioClock.swift
//  radio
//
//  Created by Foster Chacon on 28/10/26.
//

// radio/Core/Support/RadioClock.swift

import Foundation

/// The station schedule is always in Colombia time, whatever the device time zone is.
enum RadioClock {
    nonisolated static let timeZone = TimeZone(identifier: "America/Bogota") ?? .current

    /// ISO weekday (1 = Monday ... 7 = Sunday) and minutes since midnight, in Colombia time.
    nonisolated static func now(_ date: Date = .now) -> (isoDay: Int, minutes: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let weekday = parts.weekday ?? 1 // Calendar: 1 = Sunday ... 7 = Saturday
        return ((weekday + 5) % 7 + 1, (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }
}
