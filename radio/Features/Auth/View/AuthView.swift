// radio/Features/Auth/View/AuthView.swift

import SwiftUI

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.ufpsRed.opacity(0.28), radius: 10, y: 4)

                        Text("UFPS Radio 95.2 FM")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        Text("Universidad Francisco de Paula Santander")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Modo", selection: $viewModel.mode) {
                        ForEach(AuthViewModel.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    TextField("Correo electrónico", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Contraseña", text: $viewModel.password)
                        .textContentType(viewModel.mode == .signUp ? .newPassword : .password)

                    if viewModel.mode == .signUp {
                        SecureField("Confirmar contraseña", text: $viewModel.confirmPassword)
                            .textContentType(.newPassword)
                    }
                } footer: {
                    if viewModel.passwordsMismatch {
                        Text("Las contraseñas no coinciden.").foregroundStyle(Color.ufpsRed)
                    } else if viewModel.mode == .signUp {
                        Text("Mínimo 6 caracteres.")
                    }
                }

                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(Color.ufpsRed) }
                }
                if let message = viewModel.infoMessage {
                    Section { Text(message).foregroundStyle(.green) }
                }

                Section {
                    Button {
                        Task { await viewModel.submit(using: session) }
                    } label: {
                        if viewModel.isWorking {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        } else {
                            Text(viewModel.mode == .signIn ? "Entrar" : "Crear cuenta")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ufpsRed)
                    .disabled(!viewModel.canSubmit || viewModel.isWorking)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if viewModel.mode == .signIn {
                    Section {
                        Button("¿Olvidaste tu contraseña?") {
                            Task { await viewModel.resetPassword(using: session) }
                        }
                        .foregroundStyle(Color.ufpsRed)
                        .disabled(viewModel.isWorking)
                    }
                }
            }
            .navigationTitle("UFPS Radio 95.2")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AuthView()
        .environment(SessionStore(previewState: .signedOut))
}
