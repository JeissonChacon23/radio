// radio/App/RootView.swift

import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView("Cargando…")
            case .signedOut:
                AuthView()
            case .needsProfile:
                RegistroView()
            case .ready:
                MainTabView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("Sin conexión", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") { Task { await session.start() } }
                    Button("Usar otra cuenta") { session.signOut() }
                }
            }
        }
        .task {
            guard !RuntimeEnvironment.isPreview else { return }
            await session.start()
        }
    }
}

#Preview("Sin sesión") {
    RootView()
        .environment(SessionStore(previewState: .signedOut))
        .environment(RadioPlayerManager())
        .environment(PodcastPlayerManager())
}

#Preview("Con sesión") {
    RootView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager())
        .environment(PodcastPlayerManager())
}

#Preview("Error") {
    RootView()
        .environment(SessionStore(previewState: .failed("No se pudo cargar tu perfil. Revisa tu conexión e inténtalo de nuevo.")))
        .environment(RadioPlayerManager())
        .environment(PodcastPlayerManager())
}
