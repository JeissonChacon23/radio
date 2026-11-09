// radio/Features/Podcast/View/PodcastRow.swift

import SwiftUI

struct PodcastRow: View {
    let episode: PodcastEpisode

    @Environment(PodcastPlayerManager.self) private var player

    private var isCurrent: Bool { player.current?.id == episode.id }

    private var icon: String {
        guard isCurrent else { return "play.circle" }
        return player.isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            DriveArtworkView(id: episode.imageId, cornerRadius: 10, pixelSize: 256)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.programName)
                    .font(.headline)
                Text(episode.dateAndTimeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !episode.hosts.isEmpty {
                    Text("Locutores: \(episode.hosts.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        PodcastRow(
            episode: PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                                    airDate: .now, airTime: "10:00", hosts: ["Ana", "Luis"], imageId: nil, audioId: "x")
        )
    }
    .environment(PodcastPlayerManager())
}
