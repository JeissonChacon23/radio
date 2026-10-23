// radio/Features/Auth/View/AuthView.swift

//
//  AuthView.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

// radio/Features/Auth/View/AuthView.swift

import SwiftUI

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Modo", selection: $viewModel.mode) {
                        ForEach(AuthViewModel.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Correo", text: $viewModel.email)
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
                        Text("Las contraseñas no coinciden.").foregroundStyle(.red)
                    } else if viewModel.mode == .signUp {
                        Text("Mínimo 6 caracteres.")
                    }
                }

                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(.red) }
                }
                if let message = viewModel.infoMessage {
                    Section { Text(message).foregroundStyle(.green) }
                }

                Section {
                    Button {
                        Task { await viewModel.submit(using: session) }
                    } label: {
                        if viewModel.isWorking {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(viewModel.mode == .signIn ? "Entrar" : "Crear cuenta")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isWorking)
                }

                if viewModel.mode == .signIn {
                    Section {
                        Button("¿Olvidaste tu contraseña?") {
                            Task { await viewModel.resetPassword(using: session) }
                        }
                        .disabled(viewModel.isWorking)
                    }
                }
            }
            .navigationTitle("UFPS Radio 95.2")
        }
    }
}

#Preview {
    AuthView()
        .environment(SessionStore(previewState: .signedOut))
}
