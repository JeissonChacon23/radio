// radio/Features/Cuenta/View/CuentaView.swift

//
//  CuentaView.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

// radio/Features/Cuenta/View/CuentaView.swift

import SwiftUI

struct CuentaView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        NavigationStack {
            List {
                Section("Cuenta") {
                    LabeledContent("Correo", value: session.email ?? "—")
                }

                if let profile = session.profile {
                    Section("Perfil") {
                        LabeledContent("Vínculo", value: profile.profileType.title)
                        if let careerId = profile.careerId {
                            LabeledContent("Carrera (id)", value: careerId)
                        }
                        LabeledContent("Etiquetas del calendario", value: profile.audienceTags.joined(separator: ", "))
                    }
                }

                Section {
                    Button("Cerrar sesión") { session.signOut() }
                }
            }
            .navigationTitle("Mi cuenta")
        }
    }
}

#Preview {
    CuentaView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .estudiante, careerId: "ingenieria-sistemas"))))
}
