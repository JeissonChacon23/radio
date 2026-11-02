// radio/Features/Inicio/View/InicioView.swift

import SwiftUI

struct InicioView: View {
    @Environment(SessionStore.self) private var session
    @Environment(RadioPlayerManager.self) private var player
    @State private var onAir: OnAirViewModel

    /// Pass a view model only in previews. The default one is created inside the body of the
    /// initializer, which runs on the main actor.
    @MainActor
    init(onAir: OnAirViewModel? = nil) {
        _onAir = State(initialValue: onAir ?? OnAirViewModel())
    }

    var body: some View {
        NavigationStack {
            // Re-evaluates every minute, so the artwork changes when the next program starts.
            TimelineView(.everyMinute) { context in
                let programa = onAir.programaAlAire(at: context.date)

                ScrollView {
                    VStack(spacing: 20) {
                        DriveArtworkView(id: programa?.artworkId)
                            .frame(maxWidth: 340)
                            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)

                        VStack(spacing: 4) {
                            Text(programa?.name ?? "UFPS Radio 95.2 FM")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)

                            if let programa {
                                Text(programa.timeRangeText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !programa.hosts.isEmpty {
                                    Text(programa.hosts.joined(separator: ", "))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(isFailed ? Color.red : Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                // Play button: bottom-left, just above the tab bar, with the listeners below it.
                .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        PlayerView()
                        ListenersLabel(count: player.listenersCount)
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 12)
                }
                .task(id: nowPlayingKey(programa)) {
                    guard !RuntimeEnvironment.isPreview else { return }
                    await player.setOnAir(name: programa?.name, artworkId: programa?.artworkId)
                }
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let email = session.email {
                            Text(email)
                        }
                        Button("Cerrar sesión") {
                            Task {
                                await player.leavePresence() // needs the signed-in user
                                AudioFocus.stopAll() // the radio and the podcast must not keep playing
                                session.signOut()
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
        }
        .task {
            guard !RuntimeEnvironment.isPreview else { return }
            await player.prepare()
        }
        .onAppear {
            guard !RuntimeEnvironment.isPreview else { return }
            onAir.start()
            player.startListenersCount()
        }
        .onDisappear {
            onAir.stop()
            player.stopListenersCount()
        }
    }

    private func nowPlayingKey(_ programa: Programa?) -> String {
        "\(programa?.id ?? "-")|\(programa?.name ?? "")|\(programa?.artworkDriveId ?? "")"
    }

    private var isFailed: Bool {
        if case .failed = player.status { return true }
        return false
    }

    private var statusText: String {
        switch player.status {
        case .idle: "Toca para escuchar en vivo"
        case .connecting: "Conectando…"
        case .playing: "En vivo"
        case .failed(let message): message
        }
    }
}

/// Shows nothing while there are no listeners or the count is not known yet.
private struct ListenersLabel: View {
    let count: Int?

    var body: some View {
        if let count, count > 0 {
            Label(
                count == 1 ? "1 persona escuchando" : "\(count) personas escuchando",
                systemImage: "person.2.fill"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview("Sin programa al aire") {
    InicioView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager(previewListenersCount: 12))
}

#Preview("Programa al aire") {
    InicioView(
        onAir: OnAirViewModel(previewProgramas: [
            Programa(
                id: "preview",
                name: "Mañanas UFPS",
                days: [1, 2, 3, 4, 5, 6, 7],
                startTime: "00:00",
                durationMinutes: 1440,
                collective: "Colectivo Radio",
                hosts: ["Ana", "Luis"],
                artworkDriveId: ""
            )
        ])
    )
    .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
    .environment(RadioPlayerManager(previewListenersCount: 1))
}
