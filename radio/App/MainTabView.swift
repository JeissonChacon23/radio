// radio/App/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @State private var selection: AppTab = .inicio

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.inicio.title, systemImage: AppTab.inicio.systemImage, value: AppTab.inicio) {
                InicioView()
            }
            Tab(AppTab.calendario.title, systemImage: AppTab.calendario.systemImage, value: AppTab.calendario) {
                CalendarioView()
            }
            Tab(AppTab.programacion.title, systemImage: AppTab.programacion.systemImage, value: AppTab.programacion) {
                ScheduleView()
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
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager())
        .environment(PodcastPlayerManager())
}
