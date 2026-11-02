// radio/Features/Buscar/Model/BuscarModels.swift

import Foundation

struct EventItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let date: Date
    let endDate: Date?
    let link: URL?
}

extension EventItem {
    var dateRangeText: String {
        let start = date.formatted(date: .long, time: .omitted)
        guard let endDate, !Calendar.current.isDate(endDate, inSameDayAs: date) else { return start }
        return "\(start) – \(endDate.formatted(date: .long, time: .omitted))"
    }
}

struct ProgramHit: Identifiable, Hashable {
    let programa: Programa
    let matches: Int
    var id: String { programa.id }
}

struct EventHit: Identifiable, Hashable {
    let event: EventItem
    let matches: Int
    var id: String { event.id }
}

struct PodcastHit: Identifiable, Hashable {
    let episode: PodcastEpisode
    let matches: Int
    var id: String { episode.id }
}

struct SearchResults {
    var programs: [ProgramHit] = []
    var events: [EventHit] = []
    var podcasts: [PodcastHit] = []

    var isEmpty: Bool { programs.isEmpty && events.isEmpty && podcasts.isEmpty }
}

struct PodcastResult: Identifiable, Hashable {
    let id: String
    let programName: String
    let airDate: Date
    let imageId: String?   // the episode image, or the program image when the episode has none
    let audioId: String?
    let matches: Int       // how many of the searched words the episode contains
}
