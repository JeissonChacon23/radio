// radio/Features/Inicio/View/InicioView.swift

import SwiftUI

struct InicioView: View {
    @Environment(SessionStore.self) private var session
    @Environment(RadioPlayerManager.self) private var player

    /// ~1 cm en pantalla.
    private let edgeMargin: CGFloat = 56
    /// Espacio reservado abajo para el botón de reproducir y el contador.
    private let bottomReserve: CGFloat = 150
    private let maxCoverSize: CGFloat = 640

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let available = min(
                    geo.size.width - edgeMargin * 2,
                    geo.size.height - bottomReserve
                )
                let side = max(0, min(available, maxCoverSize))

                Image(RadioAssets.cover)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, bottomReserve / 2)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 10) {
                            PlayerView()
                            ListenerCountBadge()
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 16)
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
                            player.stop() // otherwise the radio would keep playing after sign out
                            session.signOut()
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    InicioView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager())
}
