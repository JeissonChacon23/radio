// radio/App/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @State private var selection: AppTab = .inicio
    @State private var inicioScrollTrigger: Int = 0

    private var selectionBinding: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newTab in
                if newTab == .inicio {
                    inicioScrollTrigger &+= 1
                }
                selection = newTab
            }
        )
    }

    var body: some View {
        TabView(selection: selectionBinding) {
            Tab(AppTab.inicio.title, systemImage: AppTab.inicio.systemImage, value: AppTab.inicio) {
                InicioView(scrollTrigger: inicioScrollTrigger)
            }
            Tab(AppTab.calendario.title, systemImage: AppTab.calendario.systemImage, value: AppTab.calendario) {
                CalendarioView()
            }
            Tab(AppTab.podcast.title, systemImage: AppTab.podcast.systemImage, value: AppTab.podcast) {
                PodcastView()
            }
            // role: .search makes the system show it as its own capsule.
            Tab(AppTab.buscar.title, systemImage: AppTab.buscar.systemImage, value: AppTab.buscar, role: .search) {
                BuscarView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.ufpsRed)
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager())
        .environment(PodcastPlayerManager())
}
