//
//  PodcastViewModel.swift
//  radio
//
//  Created by Foster Chacon on 30/10/26.
//

// radio/Features/Podcast/ViewModel/PodcastViewModel.swift

import Foundation
import Observation

@MainActor
@Observable
final class PodcastViewModel {
    private(set) var episodes: [PodcastEpisode] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    @ObservationIgnored private let service = PodcastService()

    init() {}

    #if DEBUG
    /// Only for SwiftUI previews.
    init(previewEpisodes: [PodcastEpisode]) {
        episodes = previewEpisodes
        isLoading = false
    }
    #endif

    func load() async {
        if episodes.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            episodes = try await service.listEpisodes()
        } catch {
            print("PodcastViewModel.load failed:", error)
            errorMessage = "No se pudieron cargar los podcasts."
        }
        isLoading = false
    }
}
