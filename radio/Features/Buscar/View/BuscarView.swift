// radio/Features/Buscar/View/BuscarView.swift

import SwiftUI

struct BuscarView: View {
    @Environment(SessionStore.self) private var session
    @Environment(PodcastPlayerManager.self) private var podcastPlayer
    @State private var viewModel: BuscarViewModel

    /// Pass a view model only in previews.
    @MainActor
    init(viewModel: BuscarViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? BuscarViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Buscar")
                .navigationDestination(for: EventItem.self) { event in
                    EventHitDetailView(event: event)
                }
                .searchable(text: $viewModel.query, prompt: "Programas, eventos y podcasts")
                .onSubmit(of: .search) {
                    Task {
                        await viewModel.search(audienceTags: session.profile?.audienceTags ?? ["todos"])
                    }
                }
                .safeAreaInset(edge: .bottom) { PodcastPlayerBar() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            ProgressView("Buscando…")
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView(
                "No se pudo buscar",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
        } else if !viewModel.hasSearched {
            ContentUnavailableView(
                "Busca en toda la app",
                systemImage: "magnifyingglass",
                description: Text("Escribe una o varias palabras y pulsa Buscar. Por ejemplo: tecnología, universidad, música.")
            )
        } else if viewModel.results.isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            List {
                if !viewModel.results.programs.isEmpty {
                    Section("Programas") {
                        ForEach(viewModel.results.programs) { hit in
                            ProgramHitRow(programa: hit.programa)
                        }
                    }
                }

                if !viewModel.results.events.isEmpty {
                    Section("Eventos") {
                        ForEach(viewModel.results.events) { hit in
                            NavigationLink(value: hit.event) {
                                EventHitRow(event: hit.event)
                            }
                        }
                    }
                }

                if !viewModel.results.podcasts.isEmpty {
                    Section("Podcasts") {
                        ForEach(viewModel.results.podcasts) { hit in
                            Button {
                                podcastPlayer.play(hit.episode)
                            } label: {
                                PodcastRow(episode: hit.episode)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Sin buscar") {
    BuscarView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(PodcastPlayerManager())
}

#Preview("Con resultados") {
    BuscarView(
        viewModel: BuscarViewModel(
            previewResults: SearchResults(
                programs: [
                    ProgramHit(
                        programa: Programa(
                            id: "1", name: "Mañanas UFPS", days: [1, 2, 3, 4, 5], startTime: "07:00",
                            durationMinutes: 120, collective: "Colectivo Radio", hosts: ["Ana"],
                            artworkDriveId: ""
                        ),
                        matches: 1
                    )
                ],
                events: [
                    EventHit(
                        event: EventItem(
                            id: "1", title: "Feria de emprendimiento",
                            description: "Encuentro con proyectos de estudiantes y egresados.",
                            date: .now, endDate: nil, link: nil
                        ),
                        matches: 1
                    )
                ],
                podcasts: [
                    PodcastHit(
                        episode: PodcastEpisode(
                            id: "1", programId: "1", programName: "Artistas UFPS Radio",
                            airDate: .now, imageId: nil, audioId: "x"
                        ),
                        matches: 2
                    )
                ]
            )
        )
    )
    .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
    .environment(PodcastPlayerManager())
}
