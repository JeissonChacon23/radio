// radio/Features/Inicio/View/InicioView.swift

import SwiftUI
import FirebaseFirestore
import MessageUI

struct InicioView: View {
    private static let topAnchorId = "schedule-top-anchor"

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(SessionStore.self) private var session
    @Environment(RadioPlayerManager.self) private var player
    @State private var onAir: OnAirViewModel
    @State private var showAllPast = false
    @State private var lastExpandDate: Date = .distantPast
    @State private var showingInviteSheet = false
    @State private var cuentaDestination: CuentaDestination?

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
                // Play button: bottom-left, just above the tab bar.
                .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
                    PlayerView()
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingInviteSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("\(player.listenersCount ?? 0)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Image(systemName: "wave.3.forward")
                        }
                        .foregroundStyle(Color.ufpsRed)
                        .animation(.default, value: player.listenersCount)
                    }
                    .accessibilityLabel("\(player.listenersCount ?? 0) personas escuchando en la app")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openSocial(
                            appURL: nil,
                            webURL: "https://www.facebook.com/UFPSRadio"
                        )
                    } label: {
                        FacebookMonoIcon()
                            .frame(width: 19, height: 19)
                    }
                    .accessibilityLabel("Abrir Facebook de UFPS Radio")
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openSocial(
                            appURL: "instagram://user?username=ufpsradio",
                            webURL: "https://www.instagram.com/ufpsradio/"
                        )
                    } label: {
                        InstagramMonoIcon()
                            .frame(width: 19, height: 19)
                    }
                    .accessibilityLabel("Abrir Instagram de UFPS Radio")
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let shortName = session.profile?.shortName, !shortName.isEmpty {
                            Section {
                                Text(shortName)
                            }
                        }

                        Section {
                            Button {
                                cuentaDestination = .perfil
                            } label: {
                                Label("Perfil", systemImage: "person.crop.circle")
                            }

                            Button {
                                cuentaDestination = .apariencia
                            } label: {
                                Label("Apariencia", systemImage: "circle.lefthalf.filled")
                            }

                            Button {
                                cuentaDestination = .seguridad
                            } label: {
                                Label("Cambiar contraseña", systemImage: "key.fill")
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                Task {
                                    await player.leavePresence() // needs the signed-in user
                                    AudioFocus.stopAll() // the radio and the podcast must not keep playing
                                    session.signOut()
                                }
                            } label: {
                                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.ufpsRed)
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InvitarAudienciaSheet(listenersCount: player.listenersCount ?? 0)
            }
            .sheet(item: $cuentaDestination) { destination in
                CuentaDestinationSheet(destination: destination)
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
                .frame(maxWidth: 340)
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

    private func openSocial(appURL: String?, webURL: String) {
        if let appURL, let deepLink = URL(string: appURL) {
            UIApplication.shared.open(deepLink, options: [:]) { opened in
                if !opened, let fallback = URL(string: webURL) {
                    openURL(fallback)
                }
            }
        } else if let url = URL(string: webURL) {
            openURL(url)
        }
    }
}


// MARK: - Íconos monocromáticos de redes sociales (adaptativos a modo claro y oscuro)

private struct InstagramMonoIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.primary, lineWidth: 1.75)

            Circle()
                .stroke(Color.primary, lineWidth: 1.75)
                .frame(width: 8.5, height: 8.5)

            Circle()
                .fill(Color.primary)
                .frame(width: 2.3, height: 2.3)
                .offset(x: 4.8, y: -4.8)
        }
        .padding(0.5)
    }
}

private struct FacebookMonoIcon: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.primary, lineWidth: 1.75)

            FacebookFShape()
                .fill(Color.primary)
                .frame(width: 8.5, height: 13.5)
                .padding(.trailing, 2.5)
                .padding(.bottom, 0.5)
        }
        .padding(0.5)
    }
}

private struct FacebookFShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.62, y: h))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.54))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.54))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.24))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.14),
            control: CGPoint(x: w * 0.62, y: h * 0.14)
        )
        p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.14))
        p.addLine(to: CGPoint(x: w * 0.96, y: 0))
        p.addLine(to: CGPoint(x: w * 0.70, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.25),
            control: CGPoint(x: w * 0.34, y: 0)
        )
        p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.54))
        p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.54))
        p.addLine(to: CGPoint(x: w * 0.34, y: h))
        p.closeSubpath()
        return p
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

/// RF05 / HU-03: Muestra en tiempo real cuántos usuarios de la app están escuchando (sin contar web ni FM).
private struct ListenersLabel: View {
    let count: Int?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill((count ?? 0) > 0 ? Color.ufpsRed : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
                .modifier(GentleBlinkModifier())
            Text("\(count ?? 0) En Línea")
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
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
        .contentTransition(.numericText())
        .animation(.default, value: count)
    }
}


// MARK: - Popup para invitar a aumentar la audiencia de UFPS Radio

private struct InvitarAudienciaSheet: View {
    @Environment(\.openURL) private var openURL

    let listenersCount: Int

    @State private var showingMessageComposer = false
    @State private var showingMailComposer = false
    @State private var showingActivityShare = false

    private let shareMessage = "¡Estoy escuchando UFPS Radio 95.2 FM en vivo! 📻✨ Sintoniza la emisora cultural de la Universidad Francisco de Paula Santander y acompáñanos: https://radio.ufps.edu.co/radiocontenido/colectivos_radiales"
    private let mailSubject = "Escucha UFPS Radio 95.2 FM en vivo"

    private var stationLogoImage: UIImage? {
        UIImage(named: "logo")
    }

    private var shareItems: [Any] {
        if let logo = stationLogoImage {
            return [logo, shareMessage]
        }
        return [shareMessage]
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.ufpsRed.opacity(0.12))
                        .frame(width: 58, height: 58)

                    HStack(spacing: 4) {
                        Text("\(listenersCount)")
                            .font(.title3.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Image(systemName: "wave.3.forward")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(Color.ufpsRed)
                }

                Text("¡Ayúdanos a crecer nuestra audiencia!")
                    .font(.headline.bold())
                    .multilineTextAlignment(.center)

                Text(
                    listenersCount == 1
                        ? "Ahora mismo hay 1 persona conectada en la app. Invita a tus amigos, compañeros o docentes a sintonizar UFPS Radio 95.2 FM."
                        : "Ahora mismo hay \(listenersCount) personas conectadas en la app. Invita a tus amigos, compañeros o docentes a sintonizar UFPS Radio 95.2 FM."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
            }

            HStack(spacing: 14) {
                InviteChannelButton(title: "WhatsApp") {
                    WhatsAppMonoIcon()
                } action: {
                    openWhatsApp()
                }

                InviteChannelButton(title: "iMessage") {
                    Image(systemName: "message.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.primary)
                } action: {
                    if MFMessageComposeViewController.canSendText() {
                        showingMessageComposer = true
                    } else {
                        showingActivityShare = true
                    }
                }

                InviteChannelButton(title: "Correo") {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(Color.primary)
                } action: {
                    if MFMailComposeViewController.canSendMail() {
                        showingMailComposer = true
                    } else {
                        openMailFallback()
                    }
                }
            }

            Button {
                showingActivityShare = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                    Text("Compartir por otra app")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color.ufpsRed, Color.ufpsCrimson],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .presentationDetents([.height(345)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerView(bodyText: shareMessage, logoImage: stationLogoImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(subject: mailSubject, bodyText: shareMessage, logoImage: stationLogoImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingActivityShare) {
            ActivityShareSheet(items: shareItems)
                .presentationDetents([.medium, .large])
        }
    }

    private func openWhatsApp() {
        let encoded = shareMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let appURL = URL(string: "whatsapp://send?text=\(encoded)") {
            UIApplication.shared.open(appURL, options: [:]) { opened in
                if !opened, let webURL = URL(string: "https://wa.me/?text=\(encoded)") {
                    openURL(webURL)
                }
            }
        }
    }

    private func openMailFallback() {
        let subj = mailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = shareMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let mailURL = URL(string: "mailto:?subject=\(subj)&body=\(body)") {
            openURL(mailURL)
        }
    }
}

private struct MessageComposerView: UIViewControllerRepresentable {
    let bodyText: String
    let logoImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.body = bodyText
        if let data = logoImage?.pngData(), MFMessageComposeViewController.canSendAttachments() {
            vc.addAttachmentData(data, typeIdentifier: "public.png", filename: "UFPS_Radio_95.2FM.png")
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}

private struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let bodyText: String
    let logoImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(bodyText, isHTML: false)
        if let data = logoImage?.pngData() {
            vc.addAttachmentData(data, mimeType: "image/png", fileName: "UFPS_Radio_95.2FM.png")
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeViewController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct InviteChannelButton<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon()
                    .frame(width: 28, height: 28)
                    .frame(width: 54, height: 54)
                    .background(
                        Color(.secondarySystemBackground),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Crisp vector WhatsApp logo (speech bubble with bottom-left tail + phone handset), monochrome Color.primary.
private struct WhatsAppMonoIcon: View {
    var body: some View {
        ZStack {
            WhatsAppBubbleShape()
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))

            Image(systemName: "phone.fill")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color.primary)
                .rotationEffect(.degrees(10))
                .offset(x: 0.4, y: -0.3)
        }
        .padding(1)
    }
}

private struct WhatsAppBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = w * 0.52
        let cy = h * 0.48
        let r = min(w, h) * 0.44
        var p = Path()

        // Main circle arc leaving a gap at bottom-left for the classic WhatsApp tail
        p.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: r,
            startAngle: .degrees(148),
            endAngle: .degrees(115),
            clockwise: false
        )
        // Bottom-left pointed tail
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.94))
        p.closeSubpath()
        return p
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
