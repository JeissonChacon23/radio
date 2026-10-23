// radio/App/MainTabView.swift

//
//  MainTabView.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

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
            Tab(AppTab.buscar.title, systemImage: AppTab.buscar.systemImage, value: AppTab.buscar) {
                BuscarView()
            }
            // Programación, Calendario and Buscar are added back one at a time.
        
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .invitado, careerId: nil))))
        .environment(RadioPlayerManager())
}
