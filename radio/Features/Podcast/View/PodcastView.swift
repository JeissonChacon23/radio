// radio/Features/Podcast/View/PodcastView.swift

import SwiftUI

struct PodcastView: View {
    @Environment(PodcastPlayerManager.self) private var player
    @State private var viewModel: PodcastViewModel

    /// Pass a view model only in previews.
    @MainActor
    init(viewModel: PodcastViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? PodcastViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Podcast")
                .safeAreaInset(edge: .bottom) { PodcastPlayerBar() }
                .refreshable { await viewModel.load() }
        }
        .task {
            guard !RuntimeEnvironment.isPreview else { return }
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Cargando podcasts…")
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Sin conexión", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") { Task { await viewModel.load() } }
            }
        } else if viewModel.episodes.isEmpty {
            ContentUnavailableView(
                "Aún no hay podcasts",
                systemImage: "headphones",
                description: Text("Cuando se publiquen episodios aparecerán aquí.")
            )
        } else {
            List(viewModel.episodes) { episode in
                Button {
                    player.play(episode)
                } label: {
                    PodcastRow(episode: episode)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}

#Preview("Con episodios") {
    PodcastView(
        viewModel: PodcastViewModel(previewEpisodes: [
            PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                           airDate: .now, imageId: nil, audioId: "x"),
            PodcastEpisode(id: "2", programId: "p2", programName: "Mañanas UFPS",
                           airDate: .now.addingTimeInterval(-86_400 * 7), imageId: nil, audioId: "y")
        ])
    )
    .environment(PodcastPlayerManager())
}

#Preview("Reproduciendo") {
    PodcastView(
        viewModel: PodcastViewModel(previewEpisodes: [
            PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                           airDate: .now, imageId: nil, audioId: "x")
        ])
    )
    .environment(
        PodcastPlayerManager(
            previewEpisode: PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                                           airDate: .now, imageId: nil, audioId: "x"),
            status: .playing
        )
    )
}
