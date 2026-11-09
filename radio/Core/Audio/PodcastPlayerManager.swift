// radio/Core/Audio/PodcastPlayerManager.swift

import AVFoundation
import Combine
import MediaPlayer
import Observation
import UIKit

@MainActor
@Observable
final class PodcastPlayerManager {
    enum Status: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    private(set) var current: PodcastEpisode?
    private(set) var status: Status = .idle
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    var isPlaying: Bool { status == .playing }
    var isLoading: Bool { status == .loading }

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var wantsToPlay = false
    @ObservationIgnored private var candidateURLs: [URL] = []
    @ObservationIgnored private var candidateIndex = 0
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var playbackCancellables = Set<AnyCancellable>()
    @ObservationIgnored private var lifetimeCancellables = Set<AnyCancellable>()

    init() {
        AudioFocus.register(.podcast) { [weak self] in self?.stop() }
        setupRemoteCommands()
        observeInterruptions()
    }

    #if DEBUG
    /// Only for SwiftUI previews.
    init(previewEpisode: PodcastEpisode, status: Status = .paused) {
        self.current = previewEpisode
        self.status = status
        self.duration = 3_600
        self.currentTime = 600
    }
    #endif

    // MARK: - Public API

    func play(_ episode: PodcastEpisode) {
        if current?.id == episode.id, player != nil {
            togglePlayPause() // tapping the episode that is already loaded
            return
        }

        AudioFocus.claim(.podcast) // stops the live radio, if it is playing
        teardownPlayer()
        artworkTask?.cancel()

        current = episode
        currentTime = 0
        duration = 0
        artwork = nil
        wantsToPlay = true
        status = .loading
        setSkipCommands(enabled: true)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            print("PodcastPlayerManager audio session failed:", error)
            fail("No se pudo activar el audio del dispositivo.")
            return
        }

        candidateURLs = DriveAudio.candidates(id: episode.audioId)
        candidateIndex = 0
        startCandidate()
        updateNowPlaying()
        loadArtwork(for: episode)
    }

    func pause() {
        wantsToPlay = false
        player?.pause()
        status = .paused
        updateNowPlaying()
    }

    func resume() {
        guard let episode = current else { return }
        guard player != nil else {
            play(episode) // for example, after an error
            return
        }

        AudioFocus.claim(.podcast)
        wantsToPlay = true
        status = .loading
        setSkipCommands(enabled: true)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying || isLoading {
            pause()
        } else {
            resume()
        }
    }

    func seek(to seconds: Double) {
        let limit = duration > 0 ? duration : seconds
        let target = min(max(seconds, 0), limit)
        currentTime = target
        player?.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        updateNowPlaying()
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func stop() {
        wantsToPlay = false
        artworkTask?.cancel()
        teardownPlayer()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        current = nil
        currentTime = 0
        duration = 0
        artwork = nil
        status = .idle
        setSkipCommands(enabled: false)

        AudioFocus.release(.podcast)
        if AudioFocus.current == nil {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

    // MARK: - Playback

    /// Tries each Google Drive URL in order until one of them plays.
    private func startCandidate() {
        teardownPlayer()

        guard candidateIndex < candidateURLs.count else {
            fail("No se pudo reproducir este episodio. Revisa que el audio esté compartido en Google Drive con «Cualquier persona con el enlace».")
            return
        }

        let item = AVPlayerItem(url: candidateURLs[candidateIndex])
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] status in
                guard let self, let item else { return }
                switch status {
                case .failed:
                    print("PodcastPlayerManager: this URL failed:", item.error?.localizedDescription ?? "unknown error")
                    self.candidateIndex += 1
                    self.startCandidate()
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    if seconds.isFinite, seconds > 0 {
                        self.duration = seconds
                        self.updateNowPlaying()
                    }
                default:
                    break
                }
            }
            .store(in: &playbackCancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] control in
                guard let self, self.wantsToPlay else { return }
                switch control {
                case .playing: self.status = .playing
                case .waitingToPlayAtSpecifiedRate: self.status = .loading
                case .paused: break
                @unknown default: break
                }
                self.updateNowPlaying()
            }
            .store(in: &playbackCancellables)

        NotificationCenter.default
            .publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.finished()
            }
            .store(in: &playbackCancellables)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, time.seconds.isFinite else { return }
                self.currentTime = time.seconds
            }
        }

        player.play()
    }

    private func teardownPlayer() {
        playbackCancellables.removeAll()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func finished() {
        wantsToPlay = false
        player?.seek(to: .zero)
        currentTime = 0
        status = .paused
        updateNowPlaying()
    }

    private func fail(_ message: String) {
        wantsToPlay = false
        teardownPlayer()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        status = .failed(message)
    }

    // MARK: - Lock screen and system events

    private func loadArtwork(for episode: PodcastEpisode) {
        guard let imageId = episode.imageId else { return }
        artworkTask = Task { [weak self] in
            guard let data = await DriveImageLoader.loadData(id: imageId, size: 1024),
                  !Task.isCancelled,
                  let image = UIImage(data: data) else { return }
            guard let self, self.current?.id == episode.id else { return }
            self.artwork = Self.makeArtwork(from: image)
            self.updateNowPlaying()
        }
    }

    private func setSkipCommands(enabled: Bool) {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.isEnabled = enabled
        center.skipBackwardCommand.isEnabled = enabled
        center.changePlaybackPositionCommand.isEnabled = enabled
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard AudioFocus.current == .podcast else { return }
                self?.resume()
            }
            return .success
        }
        center.pauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard AudioFocus.current == .podcast else { return }
                self?.pause()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard AudioFocus.current == .podcast else { return }
                self?.togglePlayPause()
            }
            return .success
        }
        center.skipForwardCommand.addTarget { @Sendable [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in
                guard AudioFocus.current == .podcast else { return }
                self?.skip(by: interval)
            }
            return .success
        }
        center.skipBackwardCommand.addTarget { @Sendable [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in
                guard AudioFocus.current == .podcast else { return }
                self?.skip(by: -interval)
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { @Sendable [weak self] event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            Task { @MainActor in
                guard AudioFocus.current == .podcast else { return }
                self?.seek(to: position)
            }
            return .success
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .began, self.wantsToPlay {
                    self.pause() // for example, an incoming phone call
                }
            }
            .store(in: &lifetimeCancellables)
    }

    private func updateNowPlaying() {
        guard AudioFocus.current == .podcast, let current else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.programName,
            MPMediaItemPropertyArtist: "UFPS Radio 95.2 FM · Podcast",
            MPMediaItemPropertyAlbumTitle: current.airDate.formatted(date: .long, time: .omitted),
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// nonisolated on purpose: MediaPlayer calls this closure on a background queue,
    /// and a closure created inside a MainActor method would crash there.
    nonisolated private static func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
        nonisolated(unsafe) let image = image
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
