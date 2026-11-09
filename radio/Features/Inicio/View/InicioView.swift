// radio/Features/Inicio/View/InicioView.swift

import SwiftUI

struct InicioView: View {
    private static let topAnchorId = "schedule-top-anchor"

    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionStore.self) private var session
    @Environment(RadioPlayerManager.self) private var player
    @State private var onAir: OnAirViewModel
    @State private var showAllPast = false
    @State private var lastExpandDate: Date = .distantPast

    private let scrollTrigger: Int

    /// Pass a view model only in previews. The default one is created inside the body of the
    /// initializer, which runs on the main actor.
    @MainActor
    init(onAir: OnAirViewModel? = nil, scrollTrigger: Int = 0) {
        _onAir = State(initialValue: onAir ?? OnAirViewModel())
        self.scrollTrigger = scrollTrigger
    }

    var body: some View {
        NavigationStack {
            // Re-evaluates every minute, so the artwork and schedule update when the next program starts.
            TimelineView(.everyMinute) { context in
                let programa = onAir.programaAlAire(at: context.date)
                let pasados = onAir.programasPasados(at: context.date)
                let proximos = onAir.programasProximos(at: context.date)
                let visiblePasados = showAllPast ? pasados : Array(pasados.suffix(1))
                let extraPastCount = max(pasados.count - 1, 0)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            Color.clear
                                .frame(height: 0)
                                .id(Self.topAnchorId)

                            if !visiblePasados.isEmpty {
                                ScheduleSectionView(
                                    title: "PREVIO",
                                    systemImage: "clock.arrow.circlepath",
                                    programas: visiblePasados,
                                    isPast: true,
                                    canTogglePast: extraPastCount > 0,
                                    isExpanded: showAllPast,
                                    onTogglePast: {
                                        if showAllPast {
                                            retractPastPrograms(proxy: proxy)
                                        } else {
                                            expandPastPrograms()
                                        }
                                    }
                                )
                            }

                            nowPlayingHero(programa: programa)

                            if !proximos.isEmpty {
                                ScheduleSectionView(
                                    title: "PRÓXIMO",
                                    systemImage: "calendar.badge.clock",
                                    programas: proximos,
                                    isPast: false
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                        .frame(maxWidth: .infinity)
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.y + geo.contentInsets.top
                    } action: { oldOffset, newOffset in
                        guard extraPastCount > 0 else { return }

                        if !showAllPast {
                            // Pull down at the top to reveal earlier past programs.
                            if newOffset < -42 {
                                expandPastPrograms()
                            }
                        } else {
                            // When scrolling back down to the current program, retract the extra past programs
                            // so the initial layout (with large "Programación" + 1 previous program) is restored.
                            let elapsed = Date.now.timeIntervalSince(lastExpandDate)
                            let retractThreshold = CGFloat(extraPastCount) * 72
                            if elapsed > 0.45, newOffset > oldOffset, newOffset >= retractThreshold {
                                retractPastPrograms(proxy: proxy)
                            }
                        }
                    }
                    .onAppear {
                        resetToInitialPosition(proxy: proxy, animated: false)
                    }
                    .onChange(of: scrollTrigger) { _, _ in
                        resetToInitialPosition(proxy: proxy, animated: true)
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            resetToInitialPosition(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: nowPlayingKey(programa)) { _, _ in
                        resetToInitialPosition(proxy: proxy, animated: true)
                    }
                }
                // Play button: bottom-left, just above the tab bar, with the listeners below it.
                .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        PlayerView()
                        ListenersLabel(count: player.listenersCount)
                    }
                    .padding(.leading, 28)
                    .padding(.bottom, 16)
                }
                .task(id: nowPlayingKey(programa)) {
                    guard !RuntimeEnvironment.isPreview else { return }
                    await player.setOnAir(name: programa?.name, artworkId: programa?.artworkId)
                }
            }
            .navigationTitle("Programación")
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
                            .foregroundStyle(Color.ufpsRed)
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

    @ViewBuilder
    private func nowPlayingHero(programa: Programa?) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .modifier(GentleBlinkModifier())
                Text(programa != nil ? "AL AIRE · 95.2 FM" : "UFPS RADIO · 95.2 FM")
                    .font(.caption.bold())
                    .tracking(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color.ufpsRed, Color.ufpsCrimson],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )

            DriveArtworkView(id: programa?.artworkId)
                .frame(maxWidth: 280)
                .scaleEffect(player.isPlaying ? 1.0 : 0.88)
                .shadow(
                    color: Color.ufpsCrimson.opacity(player.isPlaying ? 0.28 : 0.14),
                    radius: player.isPlaying ? 22 : 12,
                    y: player.isPlaying ? 12 : 6
                )
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: player.isPlaying)

            VStack(spacing: 4) {
                Text(programa?.name ?? "UFPS Radio 95.2 FM")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let programa {
                    Text(programa.timeRangeText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ufpsRed)
                    if !programa.collective.isEmpty {
                        Text(programa.collective)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if !programa.hosts.isEmpty {
                        Text(programa.hosts.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Emisora Cultural Universidad Francisco de Paula Santander")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if case .failed(let message) = player.status {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.ufpsRed)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }

    private func expandPastPrograms() {
        lastExpandDate = .now
        withAnimation(.snappy) {
            showAllPast = true
        }
    }

    private func retractPastPrograms(proxy: ScrollViewProxy) {
        withAnimation(.snappy) {
            showAllPast = false
            proxy.scrollTo(Self.topAnchorId, anchor: .top)
        }
    }

    private func resetToInitialPosition(proxy: ScrollViewProxy, animated: Bool) {
        showAllPast = false
        Task { @MainActor in
            if animated {
                withAnimation(.snappy) {
                    proxy.scrollTo(Self.topAnchorId, anchor: .top)
                }
            } else {
                proxy.scrollTo(Self.topAnchorId, anchor: .top)
            }
        }
    }

    private func nowPlayingKey(_ programa: Programa?) -> String {
        "\(programa?.id ?? "-")|\(programa?.name ?? "")|\(programa?.artworkDriveId ?? "")"
    }
}

// MARK: - Efecto de parpadeo suave

private struct GentleBlinkModifier: ViewModifier {
    @State private var isDimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(isDimmed ? 0.25 : 1.0)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isDimmed
            )
            .onAppear {
                isDimmed = true
            }
    }
}

// MARK: - Secciones de programación del día

private struct ScheduleSectionView: View {
    let title: String
    let systemImage: String
    let programas: [Programa]
    let isPast: Bool
    var canTogglePast: Bool = false
    var isExpanded: Bool = false
    var onTogglePast: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isPast {
                sectionHeader
            }

            VStack(spacing: 10) {
                ForEach(programas) { programa in
                    ScheduleProgramCard(programa: programa, isPast: isPast)
                        .id(isPast ? "past-\(programa.id)" : "next-\(programa.id)")
                }
            }

            if isPast {
                if canTogglePast, let onTogglePast {
                    Button(action: onTogglePast) {
                        HStack(spacing: 6) {
                            sectionHeader
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                } else {
                    sectionHeader
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionHeader: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

private struct ScheduleProgramCard: View {
    let programa: Programa
    let isPast: Bool

    var body: some View {
        HStack(spacing: 14) {
            DriveArtworkView(id: programa.artworkId, cornerRadius: 12, pixelSize: 256)
                .frame(width: 54, height: 54)
                .opacity(isPast ? 0.65 : 1.0)

            VStack(alignment: .leading, spacing: 3) {
                Text(programa.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .lineLimit(1)

                Text(programa.timeRangeText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isPast ? Color.secondary : Color.ufpsRed)

                if !programa.hosts.isEmpty {
                    Text(programa.hosts.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !programa.collective.isEmpty {
                    Text(programa.collective)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            Color(.secondarySystemBackground).opacity(isPast ? 0.6 : 1.0),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

/// Shows nothing while there are no listeners or the count is not known yet.
private struct ListenersLabel: View {
    let count: Int?

    var body: some View {
        if let count, count > 0 {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.ufpsRed)
                    .frame(width: 7, height: 7)
                    .modifier(GentleBlinkModifier())
                Text("\(count) En Línea")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.ufpsRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.ufpsRed.opacity(0.22), lineWidth: 1)
            )
        }
    }
}

#Preview("Sin programa al aire") {
    InicioView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager(previewListenersCount: 12))
}

#Preview("Programación del día") {
    InicioView(
        onAir: OnAirViewModel(previewProgramas: [
            Programa(
                id: "past-1",
                name: "Madrugada UFPS",
                days: [1, 2, 3, 4, 5, 6, 7],
                startTime: "00:00",
                durationMinutes: 30,
                collective: "Archivo",
                hosts: ["Laura"],
                artworkDriveId: ""
            ),
            Programa(
                id: "past-2",
                name: "Primera Hora UFPS",
                days: [1, 2, 3, 4, 5, 6, 7],
                startTime: "00:30",
                durationMinutes: 30,
                collective: "Informativo",
                hosts: ["Carlos"],
                artworkDriveId: ""
            ),
            Programa(
                id: "live",
                name: "Mañanas UFPS",
                days: [1, 2, 3, 4, 5, 6, 7],
                startTime: "01:00",
                durationMinutes: 1320,
                collective: "Colectivo Radio",
                hosts: ["Ana", "Luis"],
                artworkDriveId: ""
            ),
            Programa(
                id: "next-1",
                name: "Noches Culturales",
                days: [1, 2, 3, 4, 5, 6, 7],
                startTime: "23:00",
                durationMinutes: 60,
                collective: "Cultura UFPS",
                hosts: ["Sofía"],
                artworkDriveId: ""
            )
        ])
    )
    .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
    .environment(RadioPlayerManager(previewListenersCount: 4))
}
