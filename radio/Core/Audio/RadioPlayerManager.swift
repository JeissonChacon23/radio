// radio/Core/Audio/RadioPlayerManager.swift

import AVFoundation
import Combine
import FirebaseFirestore
import MediaPlayer
import Observation
import UIKit

@MainActor
@Observable
final class RadioPlayerManager {
    enum Status: Equatable {
        case idle
        case connecting
        case playing
        case failed(String)
    }

    /// How often the Inicio screen asks for the number of listeners.
    private static let countInterval: Duration = .seconds(10)

    private(set) var status: Status = .idle

    /// Devices listening to the radio right now (nil until it is known).
    private(set) var listenersCount: Int?

    /// True while the user wants to listen (connecting or playing).
    var isActive: Bool {
        switch status {
        case .connecting, .playing: true
        case .idle, .failed: false
        }
    }

    @ObservationIgnored private var streamURL: URL?
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var wantsToPlay = false
    @ObservationIgnored private var playbackCancellables = Set<AnyCancellable>()
    @ObservationIgnored private var lifetimeCancellables = Set<AnyCancellable>()

    // Lock screen information: the program that is on air right now.
    @ObservationIgnored private var nowPlayingTitle: String?
    @ObservationIgnored private var nowPlayingArtwork: MPMediaItemArtwork?

    // Listeners counter (ListenerPresenceService): join while playing, count while Inicio is open.
    @ObservationIgnored private let presence = ListenerPresenceService()
    @ObservationIgnored private var presenceTask: Task<Void, Never>?
    @ObservationIgnored private var countTask: Task<Void, Never>?

    init() {
        AudioFocus.register(.radio) { [weak self] in self?.stop() }
        setupRemoteCommands()
        observeInterruptions()
    }

    #if DEBUG
    /// Only for SwiftUI previews.
    convenience init(previewListenersCount: Int) {
        self.init()
        listenersCount = previewListenersCount
    }
    #endif

    // MARK: - Public API

    /// Finds the stream URL: Firestore first (config/app.streamUrl), then the fallback in code.
    func prepare() async {
        guard streamURL == nil else { return }

        if let remote = await Self.remoteStreamURL() {
            streamURL = remote
            return
        }
        if let fallback = RadioConfig.fallbackStreamURL {
            print("RadioPlayerManager: using the fallback stream URL")
            streamURL = fallback
        }
    }

    func play() async {
        AudioFocus.claim(.radio) // stops the podcast, if one is playing
        wantsToPlay = true
        status = .connecting
        startPresence() // this device is counted right away, without waiting for the stream
        await prepare()
        guard wantsToPlay else { return } // the user pressed stop while loading

        guard let url = streamURL else {
            fail("La señal en vivo no está disponible en este momento.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("RadioPlayerManager audio session failed:", error)
            fail("No se pudo activar el audio del dispositivo.")
            return
        }

        startPlayback(url: url)
    }

    func stop() {
        wantsToPlay = false
        teardownPlayer()
        deactivateSession()
        stopPresence()
        status = .idle
        AudioFocus.release(.radio)
        updateNowPlaying()
    }

    func toggle() async {
        if isActive {
            stop()
        } else {
            await play()
        }
    }

    // MARK: - Names used by PlayerView

    var isPlaying: Bool { status == .playing }
    var isBuffering: Bool { status == .connecting }

    func togglePlayback() {
        Task { await toggle() }
    }

    /// Called by the Inicio screen whenever the program on air changes.
    func setOnAir(name: String?, artworkId: String?) async {
        nowPlayingTitle = name
        nowPlayingArtwork = nil
        updateNowPlaying() // the title shows up right away

        guard let artworkId else { return }
        let data = await DriveImageLoader.loadData(id: artworkId, size: 1024)
        guard !Task.isCancelled else { return } // another program started while loading

        if let data, let image = UIImage(data: data) {
            nowPlayingArtwork = Self.makeArtwork(from: image)
            updateNowPlaying()
        }
    }

    // MARK: - Listeners counter

    /// Refreshes the count every few seconds. The Inicio screen calls this while it is visible.
    func startListenersCount() {
        guard countTask == nil else { return }
        countTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshListenersCount()
                try? await Task.sleep(for: Self.countInterval)
            }
        }
    }

    func stopListenersCount() {
        countTask?.cancel()
        countTask = nil
    }

    /// Removes this device from the listeners right away. It needs the signed-in user,
    /// so it must be called before signing out.
    func leavePresence() async {
        let task = presenceTask
        presenceTask?.cancel()
        presenceTask = nil
        await task?.value // lets a join that is still in flight finish before leaving
        await presence.leave()
    }

    private func refreshListenersCount() async {
        do {
            listenersCount = try await presence.currentCount()
        } catch {
            print("RadioPlayerManager: could not read the listeners count:", error)
        }
    }

    private func startPresence() {
        guard presenceTask == nil else { return }
        presenceTask = Task { [weak self, presence] in
            while !Task.isCancelled {
                await presence.join()
                await self?.refreshListenersCount() // shows the new number right away
                try? await Task.sleep(for: .seconds(60)) // the active window is 150 seconds
            }
        }
    }

    private func stopPresence() {
        guard presenceTask != nil else { return }
        let task = presenceTask
        task?.cancel()
        presenceTask = nil

        Task { [weak self, presence] in
            await task?.value // lets a join that is still in flight finish before leaving
            guard let self, self.presenceTask == nil else { return } // the user pressed play again
            await presence.leave()
            await self.refreshListenersCount()
        }
    }

    // MARK: - Stream URL

    /// Reads config/app.streamUrl. http is accepted too, because the station's stream may need it
    /// (it then also needs an App Transport Security exception in Info.plist).
    private static func remoteStreamURL() async -> URL? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("config").document("app").getDocument()
            guard let text = snapshot.data()?["streamUrl"] as? String else {
                print("RadioPlayerManager: config/app has no streamUrl field")
                return nil
            }
            guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = url.scheme, ["http", "https"].contains(scheme) else {
                print("RadioPlayerManager: streamUrl is not a valid URL:", text)
                return nil
            }
            return url
        } catch {
            print("RadioPlayerManager: could not read config/app:", error)
            return nil
        }
    }

    // MARK: - Playback

    private func startPlayback(url: URL) {
        teardownPlayer()

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed {
                    self?.fail("No se pudo conectar con la señal en vivo.")
                }
            }
            .store(in: &playbackCancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] control in
                guard let self, self.wantsToPlay else { return }
                switch control {
                case .playing:
                    self.status = .playing
                case .waitingToPlayAtSpecifiedRate:
                    self.status = .connecting
                case .paused:
                    break
                @unknown default:
                    break
                }
                self.updateNowPlaying()
            }
            .store(in: &playbackCancellables)

        NotificationCenter.default
            .publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fail("Se perdió la conexión con la señal en vivo.")
            }
            .store(in: &playbackCancellables)

        player.play()
        updateNowPlaying()
    }

    /// Dropping the item (instead of pausing) makes the next play start from the live point.
    private func teardownPlayer() {
        playbackCancellables.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func fail(_ message: String) {
        wantsToPlay = false
        teardownPlayer()
        deactivateSession()
        stopPresence()
        status = .failed(message)
        AudioFocus.release(.radio)
        updateNowPlaying()
    }

    // MARK: - Lock screen and system events

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard AudioFocus.current != .podcast else { return }
                await self?.play()
            }
            return .success
        }
        center.pauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard AudioFocus.current != .podcast else { return }
                self?.stop()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard AudioFocus.current != .podcast else { return }
                await self?.toggle()
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
                    self.stop() // for example, an incoming phone call
                }
            }
            .store(in: &lifetimeCancellables)
    }

    private func updateNowPlaying() {
        // While a podcast plays, the lock screen belongs to the podcast.
        guard AudioFocus.current != .podcast else { return }

        let center = MPNowPlayingInfoCenter.default()
        guard wantsToPlay else {
            center.nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle ?? "UFPS Radio 95.2 FM",
            MPMediaItemPropertyArtist: "UFPS Radio 95.2 FM · En vivo",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0
        ]
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        center.nowPlayingInfo = info
    }

    /// nonisolated on purpose: MediaPlayer calls this closure on a background queue,
    /// and a closure created inside a MainActor method would crash there.
    nonisolated private static func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
        nonisolated(unsafe) let image = image
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
