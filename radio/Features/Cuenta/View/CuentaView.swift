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
                            LabeledContent("Programa", value: careerId)
                        }
                        if let departmentId = profile.departmentId {
                            LabeledContent("Departamento", value: departmentId.replacingOccurrences(of: "dept:", with: ""))
                        }
                        Button("Actualizar vínculo o programa") {
                            session.editProfile()
                        }
                    }
                }

                Section {
                    Button("Cerrar sesión", role: .destructive) { session.signOut() }
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
