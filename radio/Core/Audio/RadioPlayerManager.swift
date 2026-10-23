// radio/Core/Audio/RadioPlayerManager.swift

import AVFoundation
import MediaPlayer
import UIKit
import Observation
import Combine

enum RadioAssets {
    /// Nombre del asset con la carátula (1024x1024).
    static let cover = "logo"
}

@MainActor
@Observable
final class RadioPlayerManager {

    static let shared = RadioPlayerManager()

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var statusCancellable: AnyCancellable?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private let presence = ListenerPresenceService()

    // TODO: Reemplazar por la URL directa del stream de audio (no la página web)
    private let streamURL = URL(string: "https://apps.ufps.edu.co/emisoraufps")!

    init() {
        guard !RuntimeEnvironment.isPreview else { return }
        configureAudioCategory()
        configureRemoteCommandCenter()
    }

    // MARK: - Audio session

    private func configureAudioCategory() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            print("Error configurando categoría de AVAudioSession: \(error)")
        }
    }

    private func activateAudioSession() async {
        await Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Error activando AVAudioSession: \(error)")
            }
        }.value
    }

    // MARK: - Controles

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !isPlaying else { return }

        isPlaying = true
        isBuffering = true
        updateNowPlayingInfo()
        startPresence()

        Task {
            await activateAudioSession()
            guard isPlaying else { return }

            // Siempre se crea un reproductor nuevo para conectarse al directo
            if player == nil {
                let item = AVPlayerItem(url: streamURL)
                let newPlayer = AVPlayer(playerItem: item)
                player = newPlayer
                observeStatus(of: newPlayer)
            }
            player?.play()
        }
    }

    /// En una emisora en vivo, pausar descarta el buffer para no retomar audio atrasado.
    func pause() {
        releasePlayer()
        isPlaying = false
        isBuffering = false
        updateNowPlayingInfo()
        stopPresence()
    }

    func stop() {
        releasePlayer()
        isPlaying = false
        isBuffering = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        stopPresence()
    }

    private func releasePlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        statusCancellable = nil
    }

    // MARK: - Presencia (conteo de oyentes)

    private func startPresence() {
        guard !RuntimeEnvironment.isPreview else { return }
        let previous = heartbeatTask
        previous?.cancel()

        heartbeatTask = Task { [presence] in
            await previous?.value
            while !Task.isCancelled {
                await presence.join()
                try? await Task.sleep(for: .seconds(60))
            }
            await presence.leave()
        }
    }

    private func stopPresence() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Buffering

    private func observeStatus(of player: AVPlayer) {
        statusCancellable = player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, self.isPlaying else { return }
                self.isBuffering = (status == .waitingToPlayAtSpecifiedRate)
            }
    }

    // MARK: - Remote Command Center

    private func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
    }

    // MARK: - Now Playing

    private func updateNowPlayingInfo() {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: "UFPS Radio 95.2",
            MPMediaItemPropertyArtist: "En vivo",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let image = UIImage(named: RadioAssets.cover) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
