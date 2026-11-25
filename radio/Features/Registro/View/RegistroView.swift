// radio/Features/Registro/View/RegistroView.swift

import SwiftUI

struct RegistroView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = RegistroViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Tus datos personales") {
                    TextField("Nombre(s)", text: $viewModel.firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                    TextField("Apellidos", text: $viewModel.lastName)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)
                    TextField("Número de celular", text: $viewModel.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("¿Cuál es tu vínculo con la universidad?") {
                    ForEach(ProfileType.allCases) { type in
                        Button {
                            viewModel.select(type)
                        } label: {
                            HStack {
                                Text(type.title)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if viewModel.profileType == type {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primary)
                    }
                }

                // Estudiante: ingresa su código estudiantil de 7 dígitos y se detecta automáticamente su carrera
                if viewModel.profileType == .estudiante {
                    Section {
                        HStack {
                            Image(systemName: "number.square.fill")
                                .foregroundStyle(Color.ufpsRed)
                            TextField("Código estudiantil (7 dígitos, ej. 1151594)", text: $viewModel.studentCode)
                                .keyboardType(.numberPad)
                                .monospacedDigit()
                            Spacer()
                            Text("\(viewModel.studentCode.count)/7")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(viewModel.studentCode.count == 7 ? Color.green : Color.secondary)
                        }

                        if viewModel.isLoadingCareers {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Cargando carreras UFPS…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let career = viewModel.detectedCareerFromCode {
                            LabeledContent("Carrera", value: career.name)
                            LabeledContent("Departamento", value: Career.cleanDepartmentName(career.department))
                            LabeledContent("Facultad", value: career.faculty)
                        }
                    } header: {
                        Text("Código estudiantil y carrera")
                    } footer: {
                        if let validationMsg = viewModel.studentCodeValidationMessage {
                            Label(validationMsg, systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(viewModel.studentCode.isEmpty ? Color.secondary : Color.ufpsRed)
                        } else if let career = viewModel.detectedCareerFromCode {
                            Label(
                                "Código válido (7 dígitos). Perteneces a \(career.name) (código \(career.code)).",
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.green)
                        }
                    }
                }

                // Egresado: selecciona el programa del que se graduó
                if viewModel.profileType == .egresado {
                    Section("Programa del que eres egresado") {
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
                                LabeledContent("Departamento", value: Career.cleanDepartmentName(career.department))
                                LabeledContent("Facultad", value: career.faculty)
                            }
                        }
                    }
                }

                // Docente / Personal UFPS: selecciona el departamento al que pertenece
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
                                    value: viewModel.selectedDepartment.map { Career.cleanDepartmentName($0.name) } ?? "Selecciona…"
                                )
                            }
                            if let dept = viewModel.selectedDepartment {
                                LabeledContent("Facultad", value: dept.faculty)
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.primary, Color.ufpsRed)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.submit(using: session) }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        } else {
                            Text("Guardar y continuar")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ufpsRed)
                    .disabled(!viewModel.canSubmit || viewModel.isSaving)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Completa tu perfil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salir") { session.signOut() }
                        .foregroundStyle(.primary)
                }
            }
            .onAppear {
                viewModel.prefill(from: session)
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
