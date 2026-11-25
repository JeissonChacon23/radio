// radio/Features/Podcast/View/PodcastPlayerBar.swift

import SwiftUI

/// Mini player: shows nothing when no episode is loaded.
struct PodcastPlayerBar: View {
    @Environment(PodcastPlayerManager.self) private var player

    @State private var isScrubbing = false
    @State private var scrubTime = 0.0
    @State private var starredPodcastIds: Set<String> = PodcastViewModel.loadStarredIds()

    private var failureMessage: String? {
        if case .failed(let message) = player.status { return message }
        return nil
    }

    var body: some View {
        if let episode = player.current {
            VStack(spacing: 0) {
                // Franja superior institucional UFPS
                LinearGradient(
                    colors: [Color.ufpsRed, Color.ufpsCrimson],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 3)

                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        DriveArtworkView(id: episode.imageId, cornerRadius: 10, pixelSize: 1024)
                            .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.programName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(failureMessage ?? episode.dateAndTimeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        let isStarred = starredPodcastIds.contains(episode.id)
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                                PodcastViewModel.toggleEpisodeStar(id: episode.id)
                                starredPodcastIds = PodcastViewModel.loadStarredIds()
                            }
                        } label: {
                            Image(systemName: isStarred ? "star.fill" : "star")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isStarred ? Color.ufpsRed : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 32, height: 32)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                        .accessibilityLabel(isStarred ? "Quitar de destacados" : "Destacar podcast")

                        Button { player.skip(by: -15) } label: {
                            Image(systemName: "gobackward.15")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                        .accessibilityLabel("Retroceder 15 segundos")

                        Button { player.togglePlayPause() } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.ufpsRed, Color.ufpsCrimson],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 38, height: 38)
                                    .shadow(color: Color.ufpsRed.opacity(0.28), radius: 5, y: 2)

                                if player.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.75)
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.subheadline.bold())
                                        .contentTransition(.symbolEffect(.replace))
                                        .foregroundStyle(.white)
                                        .offset(x: player.isPlaying ? 0 : 1)
                                }
                            }
                        }
                        .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")

                        Button { player.skip(by: 15) } label: {
                            Image(systemName: "goforward.15")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                        .accessibilityLabel("Adelantar 15 segundos")

                        Button { player.stop() } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                        .accessibilityLabel("Cerrar reproductor")
                    }
                    .buttonStyle(.plain)

                    // Línea de tiempo personalizada con indicador circular (redondo)
                    RoundTimelineScrubber(
                        currentTime: isScrubbing ? scrubTime : player.currentTime,
                        duration: max(player.duration, 1),
                        isEnabled: player.duration > 0,
                        isScrubbing: $isScrubbing,
                        scrubTime: $scrubTime,
                        onSeek: { newTime in
                            player.seek(to: newTime)
                        }
                    )

                    HStack {
                        Text(Self.clock(isScrubbing ? scrubTime : player.currentTime))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Spacer()
                        Text(Self.clock(player.duration))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 4)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                starredPodcastIds = PodcastViewModel.loadStarredIds()
            }
            .onReceive(NotificationCenter.default.publisher(for: .podcastStarredIdsDidChange)) { _ in
                starredPodcastIds = PodcastViewModel.loadStarredIds()
            }
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

// MARK: - Barra de progreso con indicador perfectamente redondo

private struct RoundTimelineScrubber: View {
    let currentTime: Double
    let duration: Double
    let isEnabled: Bool
    @Binding var isScrubbing: Bool
    @Binding var scrubTime: Double
    let onSeek: (Double) -> Void

    private var progress: CGFloat {
        guard duration > 0, currentTime.isFinite else { return 0 }
        return CGFloat(min(max(currentTime / duration, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let thumbSize: CGFloat = isScrubbing ? 18 : 14
            let xPos = progress * width

            ZStack(alignment: .leading) {
                // Pista de fondo
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: 5)

                // Pista de progreso recorrida
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.ufpsRed, Color.ufpsCrimson],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(xPos, 0), height: 5)

                // Indicador perfectamente redondo (Circle)
                Circle()
                    .fill(Color.ufpsRed)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 3, y: 1)
                    .offset(x: min(max(xPos - thumbSize / 2, 0), max(width - thumbSize, 0)))
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isScrubbing)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !isScrubbing {
                            isScrubbing = true
                        }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        scrubTime = Double(ratio) * duration
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        let target = Double(ratio) * duration
                        scrubTime = target
                        isScrubbing = false
                        onSeek(target)
                    }
            )
        }
        .frame(height: 22)
        .opacity(isEnabled ? 1.0 : 0.45)
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
