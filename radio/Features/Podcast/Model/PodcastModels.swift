// radio/Features/Podcast/Model/PodcastModels.swift

import Foundation

struct PodcastEpisode: Identifiable, Hashable {
    let id: String
    let programId: String
    let programName: String
    let airDate: Date
    let airTime: String
    let hosts: [String]
    let imageId: String?   // the episode image, or the program image when the episode has none
    let audioId: String    // Google Drive file ID

    init(
        id: String,
        programId: String,
        programName: String,
        airDate: Date,
        airTime: String = "",
        hosts: [String] = [],
        imageId: String?,
        audioId: String
    ) {
        self.id = id
        self.programId = programId
        self.programName = programName
        self.airDate = airDate
        self.airTime = airTime
        self.hosts = hosts
        self.imageId = imageId
        self.audioId = audioId
    }

    var dateAndTimeText: String {
        let day = airDate.formatted(date: .long, time: .omitted)
        let clock = Evento.formattedTime(airTime, fallbackDate: airDate)
        return clock.isEmpty ? day : "\(day) · \(clock)"
    }
}
