// radio/App/RootView.swift

import SwiftUI

extension Color {
    /// Rojo institucional UFPS (#D91023 en modo claro, #EC293B en modo oscuro).
    static let ufpsRed = Color("AccentColor")
    /// Carmesí oscuro institucional UFPS (#9E0B18) para degradados y acentos profundos.
    static let ufpsCrimson = Color(red: 0.620, green: 0.043, blue: 0.094)
    /// Gris carbón institucional UFPS (#1C1C1E).
    static let ufpsDark = Color(red: 0.110, green: 0.110, blue: 0.118)
    /// Gris neutro institucional UFPS (#6E6E73).
    static let ufpsGray = Color(red: 0.431, green: 0.431, blue: 0.451)
}

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                VStack(spacing: 16) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.ufpsRed.opacity(0.25), radius: 12, y: 6)
                    ProgressView("Cargando…")
                        .tint(Color.ufpsRed)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .tint(Color.ufpsRed)
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
