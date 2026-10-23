// radio/Features/Calendario/Model/CalendarioModels.swift

//
//  CalendarioModels.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import Foundation

struct Evento: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let link: URL?
    let audience: [String]
    let date: Date
    let endDate: Date?
}

extension Evento {
    var dateRangeText: String {
        let start = date.formatted(date: .long, time: .omitted)
        guard let endDate, !Calendar.current.isDate(endDate, inSameDayAs: date) else { return start }
        return "\(start) – \(endDate.formatted(date: .long, time: .omitted))"
    }
}
