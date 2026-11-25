// radio/Features/Podcast/ViewModel/PodcastViewModel.swift

import Foundation
import Observation

extension Notification.Name {
    static let podcastStarredIdsDidChange = Notification.Name("podcast.starredEpisodeIdsDidChange")
}

@MainActor
@Observable
final class PodcastViewModel {
    static let starredStorageKey = "podcast.starredEpisodeIds"

    private(set) var episodes: [PodcastEpisode] = []
    private(set) var starredIds: Set<String> = PodcastViewModel.loadStarredIds()
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    @ObservationIgnored private let service = PodcastService()
    @ObservationIgnored private var notificationObserver: NSObjectProtocol?

    init() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .podcastStarredIdsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.starredIds = Self.loadStarredIds()
            }
        }
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

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

    // MARK: - Podcasts destacados (favoritos)

    /// Episodios que el usuario ha marcado como destacados, ordenados del más reciente al más antiguo.
    var starredEpisodes: [PodcastEpisode] {
        episodes.filter { starredIds.contains($0.id) }
    }

    func isStarred(_ episode: PodcastEpisode) -> Bool {
        starredIds.contains(episode.id)
    }

    func toggleStar(_ episode: PodcastEpisode) {
        if starredIds.contains(episode.id) {
            starredIds.remove(episode.id)
        } else {
            starredIds.insert(episode.id)
        }
        Self.saveStarredIds(starredIds)
    }

    static func isEpisodeStarred(id: String) -> Bool {
        loadStarredIds().contains(id)
    }

    static func toggleEpisodeStar(id: String) {
        var current = loadStarredIds()
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        saveStarredIds(current)
    }

    static func loadStarredIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: starredStorageKey) ?? []
        return Set(array)
    }

    private static func saveStarredIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: starredStorageKey)
        NotificationCenter.default.post(name: .podcastStarredIdsDidChange, object: nil)
    }
}
