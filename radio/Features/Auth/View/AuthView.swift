// radio/Features/Auth/View/AuthView.swift

import SwiftUI

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = AuthViewModel()
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName
        case lastName
        case phone
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundDecor

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            institutionalHeader
                                .padding(.top, 8)

                            formCard

                            bottomModeSwitch

                            Spacer(minLength: 8)

                            universityFooter
                                .padding(.bottom, 12)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: 460)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Fondo con destello institucional superior e inferior

    private var backgroundDecor: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    // Destello rojo leve en la parte superior
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.ufpsRed.opacity(0.20),
                                    Color.ufpsCrimson.opacity(0.07),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: geo.size.width * 0.78
                            )
                        )
                        .frame(width: geo.size.width * 1.35, height: geo.size.width * 1.35)
                        .position(x: geo.size.width * 0.5, y: -geo.size.width * 0.15)

                    // Destello rojo leve en la parte inferior
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.ufpsRed.opacity(0.18),
                                    Color.ufpsCrimson.opacity(0.06),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: geo.size.width * 0.78
                            )
                        )
                        .frame(width: geo.size.width * 1.35, height: geo.size.width * 1.35)
                        .position(x: geo.size.width * 0.5, y: geo.size.height + geo.size.width * 0.15)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Encabezado con "EMISORA CULTURAL", el logo y "UFPS Radio 95.2 FM"

    private var institutionalHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                Text("EMISORA CULTURAL")
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color.ufpsRed, Color.ufpsCrimson],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 154, height: 154)
                    .shadow(color: Color.black.opacity(0.14), radius: 20, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                Image("logo")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }

            Text("UFPS Radio 95.2 FM")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(
                viewModel.mode == .signIn
                    ? "Inicia sesión para sintonizar la señal en vivo, explorar podcasts y consultar la agenda universitaria."
                    : "Crea tu cuenta institucional o de invitado para personalizar tu experiencia en UFPS Radio."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tarjeta de formulario

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.mode == .signIn ? "person.badge.key.fill" : "person.crop.circle.badge.plus")
                    .font(.headline)
                    .foregroundStyle(Color.ufpsRed)

                Text(viewModel.mode == .signIn ? "Iniciar sesión" : "Crear cuenta")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 12) {
                // Campos separados de Nombre(s) y Apellidos (en modo crear cuenta)
                if viewModel.mode == .signUp {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ufpsRed)
                            .frame(width: 22)

                        TextField("Nombre(s)", text: $viewModel.firstName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .firstName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .lastName }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                focusedField == .firstName ? Color.primary.opacity(0.28) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    HStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ufpsRed)
                            .frame(width: 22)

                        TextField("Apellidos", text: $viewModel.lastName)
                            .textContentType(.familyName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .lastName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .phone }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                focusedField == .lastName ? Color.primary.opacity(0.28) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ufpsRed)
                            .frame(width: 22)

                        TextField("Número de celular", text: $viewModel.phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focusedField, equals: .phone)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                focusedField == .phone ? Color.primary.opacity(0.28) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Campo de correo
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.ufpsRed)
                        .frame(width: 22)

                    TextField("Correo electrónico", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            focusedField == .email ? Color.primary.opacity(0.28) : Color.clear,
                            lineWidth: 1
                        )
                )

                // Campo de contraseña
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.ufpsRed)
                        .frame(width: 22)

                    Group {
                        if isPasswordVisible {
                            TextField("Contraseña", text: $viewModel.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Contraseña", text: $viewModel.password)
                        }
                    }
                    .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(viewModel.mode == .signUp ? .next : .go)
                    .onSubmit {
                        if viewModel.mode == .signUp {
                            focusedField = .confirmPassword
                        } else {
                            Task { await viewModel.submit(using: session) }
                        }
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPasswordVisible ? "Ocultar contraseña" : "Mostrar contraseña")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            focusedField == .password ? Color.primary.opacity(0.28) : Color.clear,
                            lineWidth: 1
                        )
                )

                // Confirmar contraseña (solo en modo registro)
                if viewModel.mode == .signUp {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ufpsRed)
                            .frame(width: 22)

                        Group {
                            if isConfirmVisible {
                                TextField("Confirmar contraseña", text: $viewModel.confirmPassword)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Confirmar contraseña", text: $viewModel.confirmPassword)
                            }
                        }
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await viewModel.submit(using: session) }
                        }

                        Button {
                            isConfirmVisible.toggle()
                        } label: {
                            Image(systemName: isConfirmVisible ? "eye.slash.fill" : "eye.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isConfirmVisible ? "Ocultar confirmación" : "Mostrar confirmación")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                focusedField == .confirmPassword ? Color.primary.opacity(0.28) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Ayuda o validación de contraseña
            if viewModel.passwordsMismatch {
                Label("Las contraseñas no coinciden.", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.primary, Color.ufpsRed)
            } else if viewModel.mode == .signUp {
                Label("La contraseña debe tener al menos 6 caracteres.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Enlace de recuperar contraseña en modo inicio de sesión
            if viewModel.mode == .signIn {
                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.resetPassword(using: session) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "key.fill")
                                .font(.caption)
                                .foregroundStyle(Color.ufpsRed)
                            Text("¿Olvidaste tu contraseña?")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isWorking)
                }
            }

            // Mensajes de error o confirmación
            if let message = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ufpsRed)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }

            if let message = viewModel.infoMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }

            // Botón principal
            Button {
                focusedField = nil
                Task { await viewModel.submit(using: session) }
            } label: {
                ZStack {
                    if viewModel.isWorking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text(viewModel.mode == .signIn ? "Iniciar sesión" : "Crear cuenta")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.ufpsRed, Color.ufpsCrimson],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .opacity(viewModel.canSubmit && !viewModel.isWorking ? 1.0 : 0.5)
                .shadow(
                    color: Color.ufpsRed.opacity(viewModel.canSubmit ? 0.28 : 0),
                    radius: 12,
                    y: 6
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit || viewModel.isWorking)
        }
        .padding(22)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Texto inferior pequeño para cambiar entre iniciar sesión y registrarse

    private var bottomModeSwitch: some View {
        Button {
            focusedField = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                viewModel.mode = (viewModel.mode == .signIn) ? .signUp : .signIn
            }
        } label: {
            HStack(spacing: 5) {
                Text(viewModel.mode == .signIn ? "¿Aún no tienes cuenta?" : "¿Ya tienes una cuenta?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(viewModel.mode == .signIn ? "Regístrate aquí" : "Inicia sesión")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                    .underline()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pie de página con el logo de la UFPS a la izquierda y el texto a la derecha

    private var universityFooter: some View {
        HStack(spacing: 12) {
            Image("ufps_logo")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Universidad Francisco de Paula Santander")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Emisora Cultural 95.2 FM · Cúcuta")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AuthView()
        .environment(SessionStore(previewState: .signedOut))
}
