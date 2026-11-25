// radio/Features/Podcast/View/PodcastView.swift

import SwiftUI

struct PodcastView: View {
    @Environment(PodcastPlayerManager.self) private var player
    @State private var viewModel: PodcastViewModel
    @State private var selectedProgram: String?
    @State private var showingStarredSheet = false

    /// Pass a view model only in previews.
    @MainActor
    init(viewModel: PodcastViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? PodcastViewModel())
    }

    private var programNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for ep in viewModel.episodes {
            if !ep.programName.isEmpty, seen.insert(ep.programName).inserted {
                result.append(ep.programName)
            }
        }
        return result
    }

    private var filteredEpisodes: [PodcastEpisode] {
        guard let selectedProgram else { return viewModel.episodes }
        return viewModel.episodes.filter { $0.programName == selectedProgram }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundDecor

                content
            }
            .navigationTitle("Podcast")
            .safeAreaInset(edge: .bottom) { PodcastPlayerBar() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showingStarredSheet) {
                PodcastsDestacadosSheet(viewModel: viewModel)
            }
        }
        .task {
            guard !RuntimeEnvironment.isPreview else { return }
            await viewModel.load()
        }
    }

    // MARK: - Resplandor institucional sutil

    private var backgroundDecor: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.ufpsRed.opacity(0.14),
                                Color.ufpsCrimson.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: geo.size.width * 0.75
                        )
                    )
                    .frame(width: geo.size.width * 1.3, height: geo.size.width * 1.3)
                    .position(x: geo.size.width * 0.5, y: -geo.size.width * 0.2)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Cargando fonoteca…")
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Sin conexión", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.primary, Color.ufpsRed)
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") { Task { await viewModel.load() } }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.primary)
            }
        } else if viewModel.episodes.isEmpty {
            ContentUnavailableView {
                Label("Aún no hay podcasts", systemImage: "headphones")
                    .foregroundStyle(.primary, Color.ufpsRed)
            } description: {
                Text("Cuando se publiquen episodios de la emisora aparecerán aquí.")
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    institutionalBanner

                    if programNames.count > 1 {
                        programFilterChips
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.ufpsRed)

                            Text(selectedProgram ?? "Episodios disponibles")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(
                                filteredEpisodes.count == 1
                                    ? "1 episodio"
                                    : "\(filteredEpisodes.count) episodios"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            ForEach(filteredEpisodes) { episode in
                                let isCurrent = player.current?.id == episode.id
                                Button {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                                        player.play(episode)
                                    }
                                } label: {
                                    PodcastRow(
                                        episode: episode,
                                        isStarred: viewModel.isStarred(episode),
                                        onToggleStar: { viewModel.toggleStar(episode) }
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                isCurrent
                                                    ? Color.ufpsRed.opacity(0.45)
                                                    : Color.primary.opacity(0.06),
                                                lineWidth: isCurrent ? 1.5 : 1
                                            )
                                    )
                                    .shadow(
                                        color: isCurrent ? Color.ufpsRed.opacity(0.12) : Color.clear,
                                        radius: 10,
                                        y: 4
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Encabezado corporativo UFPS con acceso a Podcasts Destacados

    private var institutionalBanner: some View {
        let starredCount = viewModel.starredEpisodes.count

        return Button {
            showingStarredSheet = true
        } label: {
            HStack(spacing: 12) {
                Image("ufps_logo")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fonoteca UFPS Radio")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text("Programas emitidos bajo demanda · 95.2 FM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Image(systemName: starredCount > 0 ? "star.fill" : "star")
                        .font(.caption2.bold())
                        .foregroundStyle(starredCount > 0 ? Color.white : Color.ufpsRed)
                    Text("\(starredCount)")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(starredCount > 0 ? Color.white : Color.primary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background {
                    if starredCount > 0 {
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
            }
            .padding(14)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ver podcasts destacados")
    }

    // MARK: - Chips de filtro por programa

    private var programFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Todos",
                    isSelected: selectedProgram == nil
                ) {
                    withAnimation(.snappy) {
                        selectedProgram = nil
                    }
                }

                ForEach(programNames, id: \.self) { name in
                    FilterChip(
                        title: name,
                        isSelected: selectedProgram == name
                    ) {
                        withAnimation(.snappy) {
                            selectedProgram = (selectedProgram == name) ? nil : name
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Hoja de Podcasts Destacados por el usuario

private struct PodcastsDestacadosSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PodcastPlayerManager.self) private var player
    let viewModel: PodcastViewModel

    var body: some View {
        NavigationStack {
            Group {
                let destacados = viewModel.starredEpisodes

                if destacados.isEmpty {
                    ContentUnavailableView {
                        Label("Sin podcasts destacados", systemImage: "star.slash")
                            .foregroundStyle(.primary, Color.ufpsRed)
                    } description: {
                        Text("Toca la estrella en cualquier episodio de podcast para guardarlo aquí y escucharlo rápidamente cuando quieras.")
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(destacados) { episode in
                                let isCurrent = player.current?.id == episode.id
                                Button {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                                        player.play(episode)
                                    }
                                } label: {
                                    PodcastRow(
                                        episode: episode,
                                        isStarred: viewModel.isStarred(episode),
                                        onToggleStar: { viewModel.toggleStar(episode) }
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                isCurrent
                                                    ? Color.ufpsRed.opacity(0.45)
                                                    : Color.primary.opacity(0.06),
                                                lineWidth: isCurrent ? 1.5 : 1
                                            )
                                    )
                                    .shadow(
                                        color: isCurrent ? Color.ufpsRed.opacity(0.12) : Color.clear,
                                        radius: 10,
                                        y: 4
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Podcasts destacados")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { PodcastPlayerBar() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
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
                            .fill(Color(.secondarySystemBackground))
                    }
                }
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Con episodios") {
    PodcastView(
        viewModel: PodcastViewModel(previewEpisodes: [
            PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                           airDate: .now, airTime: "10:00", hosts: ["Ana", "Luis"], imageId: nil, audioId: "x"),
            PodcastEpisode(id: "2", programId: "p2", programName: "Mañanas UFPS",
                           airDate: .now.addingTimeInterval(-86_400 * 7), airTime: "08:00", hosts: ["Carlos"], imageId: nil, audioId: "y")
        ])
    )
    .environment(PodcastPlayerManager())
}

#Preview("Reproduciendo") {
    PodcastView(
        viewModel: PodcastViewModel(previewEpisodes: [
            PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                           airDate: .now, airTime: "10:00", hosts: ["Ana", "Luis"], imageId: nil, audioId: "x")
        ])
    )
    .environment(
        PodcastPlayerManager(
            previewEpisode: PodcastEpisode(id: "1", programId: "p1", programName: "Artistas UFPS Radio",
                                           airDate: .now, airTime: "10:00", hosts: ["Ana", "Luis"], imageId: nil, audioId: "x"),
            status: .playing
        )
    )
}
