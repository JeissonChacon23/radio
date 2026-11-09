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

                if let profileType = viewModel.profileType, profileType.requiresProgram {
                    Section(profileType == .egresado ? "Programa del que eres egresado" : "Tu programa académico") {
                        if viewModel.isLoadingCareers {
                            ProgressView()
                        } else if viewModel.careers.isEmpty {
                            Text("No hay programas disponibles por ahora.")
                                .foregroundStyle(.secondary)
                        } else {
                            NavigationLink {
                                CareerPickerView(
                                    careers: viewModel.careers,
                                    selectedCareerId: $viewModel.selectedCareerId
                                )
                            } label: {
                                LabeledContent(
                                    "Programa",
                                    value: viewModel.selectedCareer?.name ?? "Selecciona…"
                                )
                            }
                            if let career = viewModel.selectedCareer {
                                LabeledContent("Departamento", value: career.department)
                                LabeledContent("Facultad", value: career.faculty)
                            }
                        }
                    }
                }

                if let profileType = viewModel.profileType, profileType.requiresDepartment {
                    Section("Departamento al que perteneces") {
                        if viewModel.isLoadingCareers {
                            ProgressView()
                        } else if viewModel.departments.isEmpty {
                            Text("No hay departamentos disponibles por ahora.")
                                .foregroundStyle(.secondary)
                        } else {
                            NavigationLink {
                                DepartmentPickerView(
                                    departments: viewModel.departments,
                                    selectedDepartmentId: $viewModel.selectedDepartmentId
                                )
                            } label: {
                                LabeledContent(
                                    "Departamento",
                                    value: viewModel.selectedDepartment?.name ?? "Selecciona…"
                                )
                            }
                            if let dept = viewModel.selectedDepartment {
                                LabeledContent("Facultad", value: dept.faculty)
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
