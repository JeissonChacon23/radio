// radio/radioApp.swift

import SwiftUI
import FirebaseCore

@main
struct radioApp: App {
    @State private var player = RadioPlayerManager()
    @State private var podcastPlayer = PodcastPlayerManager()
    @State private var session = SessionStore()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(player)
                .environment(podcastPlayer)
        }
    }
}
