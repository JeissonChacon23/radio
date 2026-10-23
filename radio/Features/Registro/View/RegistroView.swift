// radio/Features/Registro/View/RegistroView.swift

//
//  RegistroView.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

// radio/Features/Registro/View/RegistroView.swift

import SwiftUI

struct RegistroView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = RegistroViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("¿Cuál es tu vínculo con la universidad?") {
                    ForEach(ProfileType.allCases) { type in
                        Button {
                            viewModel.select(type)
                        } label: {
                            HStack {
                                Text(type.title).foregroundStyle(.primary)
                                Spacer()
                                if viewModel.profileType == type {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                if viewModel.profileType == .estudiante {
                    Section("Tu programa académico") {
                        if viewModel.isLoadingCareers {
                            ProgressView()
                        } else if viewModel.careers.isEmpty {
                            Text("No hay carreras disponibles por ahora.")
                                .foregroundStyle(.secondary)
                        } else {
                            NavigationLink {
                                CareerPickerView(
                                    careers: viewModel.careers,
                                    selectedCareerId: $viewModel.selectedCareerId
                                )
                            } label: {
                                LabeledContent("Carrera", value: viewModel.selectedCareer?.name ?? "Selecciona…")
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task { await viewModel.submit(using: session) }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Continuar").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isSaving)
                }
            }
            .navigationTitle("Completa tu perfil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salir") { session.signOut() }
                }
            }
            .task {
                guard !RuntimeEnvironment.isPreview else { return }
                await viewModel.loadCareers()
            }
        }
    }
}

#Preview {
    RegistroView()
        .environment(SessionStore(previewState: .needsProfile))
}
