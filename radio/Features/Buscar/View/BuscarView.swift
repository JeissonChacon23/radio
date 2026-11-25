// radio/Features/Buscar/View/BuscarView.swift

import SwiftUI

struct BuscarView: View {
    @Environment(SessionStore.self) private var session
    @Environment(PodcastPlayerManager.self) private var podcastPlayer
    @State private var viewModel: BuscarViewModel
    @State private var selectedTranscriptHit: PodcastHit?
    @State private var starredPodcastIds: Set<String> = PodcastViewModel.loadStarredIds()

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
                .searchable(text: $viewModel.query, prompt: "Programas, eventos y temas de podcasts")
                .onSubmit(of: .search) {
                    Task {
                        await viewModel.search(profile: session.profile)
                    }
                }
                .safeAreaInset(edge: .bottom) { PodcastPlayerBar() }
                .sheet(item: $selectedTranscriptHit) { hit in
                    TranscripcionEpisodioSheet(hit: hit)
                }
                .onAppear {
                    starredPodcastIds = PodcastViewModel.loadStarredIds()
                }
                .onReceive(NotificationCenter.default.publisher(for: .podcastStarredIdsDidChange)) { _ in
                    starredPodcastIds = PodcastViewModel.loadStarredIds()
                }
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
                description: Text("Escribe una palabra o frase y pulsa Buscar. Se busca en programas, eventos y en las transcripciones de los podcasts.")
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
                                podcastPlayer.play(hit.episode, startAt: hit.startSeconds)
                            } label: {
                                PodcastRow(
                                    episode: hit.episode,
                                    isStarred: starredPodcastIds.contains(hit.episode.id),
                                    onToggleStar: {
                                        PodcastViewModel.toggleEpisodeStar(id: hit.episode.id)
                                        starredPodcastIds = PodcastViewModel.loadStarredIds()
                                    },
                                    matchedSnippet: hit.snippet,
                                    matchedStartSeconds: hit.startSeconds,
                                    searchTerms: hit.searchTerms,
                                    onViewTranscript: {
                                        selectedTranscriptHit = hit
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Vista detallada de la transcripción centrada donde se habló del tema

private struct TranscripcionEpisodioSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PodcastPlayerManager.self) private var player

    let hit: PodcastHit

    @State private var segments: [PodcastTranscriptSegment] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Cargando transcripción…")
                } else if segments.isEmpty {
                    ContentUnavailableView(
                        "Transcripción no disponible",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(hit.snippet ?? "No se encontraron fragmentos para este episodio.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                episodeHeader

                                ForEach(segments) { segment in
                                    let isMatched = isMatchingSegment(segment)
                                    SegmentCard(
                                        segment: segment,
                                        isMatched: isMatched,
                                        searchTerms: hit.searchTerms
                                    ) {
                                        let wordSec = QdrantConfig.interpolateWordTimestamp(
                                            in: segment.text,
                                            terms: hit.searchTerms,
                                            chunkStart: segment.startSeconds,
                                            chunkEnd: segment.endSeconds
                                        )
                                        let startAt = max(0, wordSec - QdrantConfig.leadInSeconds)
                                        player.play(hit.episode, startAt: startAt)
                                        dismiss()
                                    }
                                    .id(segment.chunkIndex)
                                }
                            }
                            .padding(20)
                        }
                        .onAppear {
                            scrollToMatchedSegment(proxy: proxy)
                        }
                    }
                }
            }
            .navigationTitle("Transcripción del podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
            .task {
                segments = await QdrantConfig.fetchEpisodeSegments(podcastId: hit.episode.id)
                isLoading = false
            }
        }
    }

    private var episodeHeader: some View {
        HStack(spacing: 12) {
            DriveArtworkView(id: hit.episode.imageId, cornerRadius: 12, pixelSize: 1024)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(hit.episode.programName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(hit.episode.dateAndTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Toca cualquier fragmento para reproducir 3 s antes")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func isMatchingSegment(_ segment: PodcastTranscriptSegment) -> Bool {
        if let matchedIdx = hit.matchedChunkIndex {
            return segment.chunkIndex == matchedIdx
        }
        return BuscarViewModel.matches(in: [segment.text], terms: hit.searchTerms) > 0
    }

    private func scrollToMatchedSegment(proxy: ScrollViewProxy) {
        let targetIndex = hit.matchedChunkIndex
            ?? segments.first(where: { isMatchingSegment($0) })?.chunkIndex
        guard let targetIndex else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.snappy) {
                proxy.scrollTo(targetIndex, anchor: .center)
            }
        }
    }
}

private struct SegmentCard: View {
    let segment: PodcastTranscriptSegment
    let isMatched: Bool
    let searchTerms: [String]
    let onPlayFromHere: () -> Void

    var body: some View {
        Button(action: onPlayFromHere) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isMatched ? Color.white : Color.ufpsRed)
                        Text(PodcastRow.formatTime(max(0, segment.startSeconds - QdrantConfig.leadInSeconds)))
                            .font(.caption2.bold())
                            .monospacedDigit()
                            .foregroundStyle(isMatched ? Color.white : Color.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        if isMatched {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.ufpsRed, Color.ufpsCrimson],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        } else {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        }
                    }

                    if isMatched {
                        Text("Coincidencia principal")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(Color.ufpsRed)
                }

                Text(PodcastRow.highlightedText(segment.text, terms: searchTerms))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isMatched ? Color.ufpsRed.opacity(0.6) : Color.primary.opacity(0.06),
                        lineWidth: isMatched ? 1.8 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Sin buscar") {
    BuscarView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(PodcastPlayerManager())
}
