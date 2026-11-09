// radio/Features/Podcast/View/PodcastPlayerBar.swift

import SwiftUI

/// Mini player: shows nothing when no episode is loaded.
struct PodcastPlayerBar: View {
    @Environment(PodcastPlayerManager.self) private var player

    @State private var isScrubbing = false
    @State private var scrubTime = 0.0

    private var failureMessage: String? {
        if case .failed(let message) = player.status { return message }
        return nil
    }

    var body: some View {
        if let episode = player.current {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    DriveArtworkView(id: episode.imageId, cornerRadius: 8, pixelSize: 256)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.programName)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(failureMessage ?? episode.dateAndTimeText)
                            .font(.caption)
                            .foregroundStyle(failureMessage == nil ? Color.secondary : Color.ufpsRed)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Button { player.skip(by: -15) } label: {
                        Image(systemName: "gobackward.15")
                    }
                    Button { player.togglePlayPause() } label: {
                        if player.isLoading {
                            ProgressView()
                                .tint(Color.ufpsRed)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundStyle(Color.ufpsRed)
                        }
                    }
                    .frame(width: 28)
                    Button { player.skip(by: 15) } label: {
                        Image(systemName: "goforward.15")
                    }
                    Button { player.stop() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(.secondary)
                }
                .font(.title3)
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubTime : player.currentTime },
                        set: { scrubTime = $0 }
                    ),
                    in: 0...max(player.duration, 1)
                ) { editing in
                    if editing { scrubTime = player.currentTime }
                    isScrubbing = editing
                    if !editing { player.seek(to: scrubTime) }
                }
                .tint(Color.ufpsRed)
                .disabled(player.duration <= 0)

                HStack {
                    Text(Self.clock(isScrubbing ? scrubTime : player.currentTime))
                    Spacer()
                    Text(Self.clock(player.duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.ufpsRed.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    VStack {
        Spacer()
        PodcastPlayerBar()
    }
    .environment(
        PodcastPlayerManager(
            previewEpisode: PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                                           airDate: .now, airTime: "10:00", hosts: ["Ana"], imageId: nil, audioId: "x"),
            status: .playing
        )
    )
}
