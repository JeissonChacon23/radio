// radio/Features/Buscar/Model/BuscarModels.swift

import Foundation

struct EventItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let specialGuest: String
    let startTime: String
    let endTime: String
    let date: Date
    let endDate: Date?
    let link: URL?

    init(
        id: String,
        title: String,
        description: String,
        specialGuest: String = "",
        startTime: String = "",
        endTime: String = "",
        date: Date,
        endDate: Date?,
        link: URL?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.specialGuest = specialGuest
        self.startTime = startTime
        self.endTime = endTime
        self.date = date
        self.endDate = endDate
        self.link = link
    }
}

extension EventItem {
    var dateRangeText: String {
        Evento(
            id: id,
            title: title,
            description: description,
            specialGuest: specialGuest,
            startTime: startTime,
            endTime: endTime,
            link: link,
            audience: [],
            date: date,
            endDate: endDate
        ).dateRangeText
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
    let imageId: String?
    let audioId: String?
    let matches: Int
}
