//
//  PodcastModels.swift
//  radio
//
//  Created by Foster Chacon on 30/10/26.
//

// radio/Features/Podcast/Model/PodcastModels.swift

import Foundation

struct PodcastEpisode: Identifiable, Hashable {
    let id: String
    let programId: String
    let programName: String
    let airDate: Date
    let imageId: String?   // the episode image, or the program image when the episode has none
    let audioId: String    // Google Drive file ID
}
