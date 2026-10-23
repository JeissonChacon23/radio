// radio/radioApp.swift

//
//  radioApp.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

// radio/radioApp.swift

import SwiftUI
import FirebaseCore

@main
struct radioApp: App {
    @State private var player = RadioPlayerManager.shared
    @State private var session = SessionStore()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(player)
        }
    }
}
