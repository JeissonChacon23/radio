// radio/Features/Cuenta/View/CuentaView.swift

import SwiftUI
import FirebaseFirestore

enum CuentaDestination: String, Identifiable {
    case perfil
    case apariencia
    case seguridad

    var id: String { rawValue }
}

struct CuentaDestinationSheet: View {
    let destination: CuentaDestination

    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    var body: some View {
        NavigationStack {
            Group {
                switch destination {
                case .perfil:
                    PerfilAcademicoView()
                case .apariencia:
                    AparienciaSelectorView()
                case .seguridad:
                    CambiarPasswordView()
                }
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}

// MARK: - 1. Vista detallada de Perfil Académico

private struct PerfilAcademicoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var careerName: String?
    @State private var departmentName: String?
    @State private var facultyName: String?
    @State private var campusName: String?
    @State private var modalityName: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Tarjeta principal de identidad
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 76, height: 76)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.ufpsRed)
                    }

                    VStack(spacing: 4) {
                        if let shortName = session.profile?.shortName, !shortName.isEmpty {
                            Text(shortName)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                        }

                        if let profile = session.profile {
                            Text(profile.profileType.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )

                // Detalles académicos
                if let profile = session.profile {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "graduationcap.fill")
                                .foregroundStyle(Color.ufpsRed)
                            Text("Información vinculada")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }

                        VStack(spacing: 0) {
                            ProfileDetailRow(
                                icon: "person.text.rectangle",
                                title: "Vínculo",
                                value: profile.profileType.title
                            )

                            if let studentCode = profile.studentCode, !studentCode.isEmpty {
                                Divider().padding(.leading, 36)
                                ProfileDetailRow(
                                    icon: "number.square.fill",
                                    title: "Código estudiantil",
                                    value: studentCode
                                )
                            }

                            if let phone = profile.phone, !phone.isEmpty {
                                Divider().padding(.leading, 36)
                                ProfileDetailRow(
                                    icon: "phone.fill",
                                    title: "Celular",
                                    value: phone
                                )
                            }

                            if let careerId = profile.careerId {
                                Divider().padding(.leading, 36)
                                ProfileDetailRow(
                                    icon: "book.closed.fill",
                                    title: "Programa académico",
                                    value: careerName ?? Self.humanizeSlug(careerId)
                                )
                            }

                            if let departmentId = profile.departmentId {
                                Divider().padding(.leading, 36)
                                ProfileDetailRow(
                                    icon: "building.columns.fill",
                                    title: "Departamento",
                                    value: Career.cleanDepartmentName(
                                        departmentName ?? profile.department ?? Self.humanizeDepartment(departmentId, careerId: profile.careerId)
                                    )
                                )
                            }

                            if let facultyName {
                                Divider().padding(.leading, 36)
                                ProfileDetailRow(
                                    icon: "building.2.fill",
                                    title: "Facultad",
                                    value: facultyName
                                )
                            }

                            if let campusName {
                                Divider().padding(.leading, 36)
                                ProfileDetailRow(
                                    icon: "mappin.and.ellipse",
                                    title: "Sede / Modalidad",
                                    value: modalityName != nil ? "\(campusName) · \(modalityName!)" : campusName
                                )
                            }
                        }
                        .padding(14)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }


                }
            }
            .padding(20)
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .task {
            guard !RuntimeEnvironment.isPreview else { return }
            await loadAcademicDetails()
        }
    }

    private func loadAcademicDetails() async {
        guard let profile = session.profile else { return }
        if let careerId = profile.careerId {
            let isOcana = careerId.contains("ocana")
            campusName = isOcana ? "Sede Ocaña" : "Sede Cúcuta"
            let fallbackDept = Career.defaultDepartment(for: careerId, faculty: "", campus: isOcana ? "ocana" : "cucuta")
            if !fallbackDept.isEmpty && fallbackDept != "Departamento de " {
                departmentName = fallbackDept
            }
            do {
                let doc = try await Firestore.firestore().collection("careers").document(careerId).getDocument()
                if let data = doc.data() {
                    if let name = data["name"] as? String { careerName = name }
                    if let dept = data["department"] as? String, !dept.isEmpty { departmentName = dept }
                    if let fac = data["faculty"] as? String, !fac.isEmpty { facultyName = fac }
                    if let mod = data["modality"] as? String, !mod.isEmpty { modalityName = mod.capitalized }
                }
            } catch {
                // Mantiene los nombres legibles locales si no hay red.
            }
        } else if let deptId = profile.departmentId {
            campusName = deptId.contains("ocana") ? "Sede Ocaña" : "Sede Cúcuta"
        }
    }

    private static func humanizeDepartment(_ departmentId: String, careerId: String?) -> String {
        if let careerId {
            let campus = careerId.contains("ocana") ? "ocana" : "cucuta"
            let mapped = Career.defaultDepartment(for: careerId, faculty: "", campus: campus)
            if !mapped.isEmpty && mapped != "Departamento de " {
                return mapped
            }
        }
        let cleaned = departmentId.replacingOccurrences(of: "dept:", with: "")
        return humanizeSlug(cleaned)
    }

    private static func humanizeSlug(_ slug: String) -> String {
        let lowercaseWords: Set<String> = ["de", "del", "e", "y", "en", "el", "la", "las", "los", "a"]
        let words = slug.split(separator: "-").map(String.init)
        return words.enumerated().map { index, word in
            if word == "ocana" { return "(Ocaña)" }
            if index > 0 && lowercaseWords.contains(word) { return word }
            return word.capitalized
        }.joined(separator: " ")
    }
}

private struct ProfileDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.ufpsRed)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - 2. Selector visual e intuitivo de Apariencia

private struct AparienciaSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Elige cómo quieres ver UFPS Radio")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("Selecciona un tema visual. El cambio se aplica al instante en todas las pantallas de la aplicación.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Tarjetas gráficas interactivas de previsualización
                HStack(spacing: 12) {
                    ForEach(AppAppearance.allCases) { option in
                        AppearancePreviewCard(
                            option: option,
                            isSelected: appearance == option
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                appearance = option
                            }
                        }
                    }
                }

                // Descripción detallada de cada modo
                VStack(spacing: 10) {
                    ForEach(AppAppearance.allCases) { option in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                appearance = option
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(Color.ufpsRed)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(Self.subtitle(for: option))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: appearance == option ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(appearance == option ? Color.ufpsRed : Color.secondary.opacity(0.4))
                            }
                            .padding(14)
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        appearance == option ? Color.ufpsRed.opacity(0.55) : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Apariencia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
    }

    private static func subtitle(for option: AppAppearance) -> String {
        switch option {
        case .system:
            "Se adapta automáticamente al modo claro u oscuro de tu iPhone o iPad."
        case .light:
            "Fondos claros y limpios ideales para entornos iluminados durante el día."
        case .dark:
            "Fondos oscuros que descansan la vista y resaltan las portadas de los programas."
        }
    }
}

private struct AppearancePreviewCard: View {
    let option: AppAppearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Miniatura ilustrada del teléfono/pantalla
                ZStack {
                    switch option {
                    case .light:
                        miniDevicePreview(isDark: false)
                    case .dark:
                        miniDevicePreview(isDark: true)
                    case .system:
                        HStack(spacing: 0) {
                            miniDeviceHalf(isDark: false, isLeading: true)
                            miniDeviceHalf(isDark: true, isLeading: false)
                        }
                    }
                }
                .frame(height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.ufpsRed : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.ufpsRed.opacity(0.22) : Color.clear,
                    radius: 8,
                    y: 4
                )

                HStack(spacing: 5) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : option.systemImage)
                        .font(.caption.bold())
                        .foregroundStyle(Color.ufpsRed)
                    Text(option.title)
                        .font(.caption.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func miniDevicePreview(isDark: Bool) -> some View {
        let bg = isDark ? Color(white: 0.11) : Color(white: 0.96)
        let card = isDark ? Color(white: 0.19) : Color.white
        let bar = isDark ? Color(white: 0.35) : Color(white: 0.82)

        return ZStack {
            bg
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.ufpsRed)
                    .frame(width: 36, height: 6)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(card)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .fill(Color.ufpsRed.opacity(0.85))
                            .frame(width: 18, height: 18)
                    )

                Capsule()
                    .fill(bar)
                    .frame(width: 44, height: 5)
                Capsule()
                    .fill(bar.opacity(0.6))
                    .frame(width: 30, height: 4)
            }
            .padding(8)
        }
    }

    private func miniDeviceHalf(isDark: Bool, isLeading: Bool) -> some View {
        let bg = isDark ? Color(white: 0.11) : Color(white: 0.96)
        let card = isDark ? Color(white: 0.19) : Color.white
        let bar = isDark ? Color(white: 0.35) : Color(white: 0.82)

        return ZStack {
            bg
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.ufpsRed)
                    .frame(width: 24, height: 6)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(card)
                    .frame(width: 32, height: 46)

                Capsule()
                    .fill(bar)
                    .frame(width: 28, height: 5)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 3. Vista de Seguridad y Cambio de Contraseña

private struct CambiarPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var passwordsMismatch: Bool {
        !confirmPassword.isEmpty && newPassword != confirmPassword
    }

    private var sameAsCurrent: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && currentPassword == newPassword
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword &&
        !sameAsCurrent
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.title3)
                        .foregroundStyle(Color.ufpsRed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cuenta vinculada")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.email ?? "—")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                SecureField("Contraseña actual", text: $currentPassword)
                    .textContentType(.password)
            } header: {
                Text("Verificación")
            }

            Section {
                SecureField("Nueva contraseña", text: $newPassword)
                    .textContentType(.newPassword)

                SecureField("Confirmar nueva contraseña", text: $confirmPassword)
                    .textContentType(.newPassword)
            } header: {
                Text("Nueva contraseña")
            } footer: {
                if passwordsMismatch {
                    Label("Las contraseñas nuevas no coinciden.", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.primary, Color.ufpsRed)
                } else if sameAsCurrent {
                    Label("La nueva contraseña debe ser diferente a la actual.", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.primary, Color.ufpsRed)
                } else {
                    Text("Usa al menos 6 caracteres.")
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.primary, Color.ufpsRed)
                }
            }

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary, .green)
                }
            }

            Section {
                Button {
                    Task { await updatePassword() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    } else {
                        Text("Actualizar contraseña")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ufpsRed)
                .disabled(!canSubmit || isSaving)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if let email = session.email {
                Section {
                    Button {
                        Task { await sendResetEmail(to: email) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(Color.ufpsRed)
                            Text("¿Olvidaste tu contraseña actual? Enviar enlace al correo")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("Cambiar contraseña")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func updatePassword() async {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            try await session.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            successMessage = "Tu contraseña se actualizó correctamente."
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        } catch {
            errorMessage = AuthErrorMessage.text(for: error)
        }
    }

    private func sendResetEmail(to email: String) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            try await session.sendPasswordReset(email: email)
            successMessage = "Te enviamos un enlace a \(email) para restablecer tu contraseña."
        } catch {
            errorMessage = AuthErrorMessage.text(for: error)
        }
    }
}

#Preview("Perfil") {
    CuentaDestinationSheet(destination: .perfil)
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .estudiante, careerId: "ingenieria-sistemas"))))
}

#Preview("Apariencia") {
    CuentaDestinationSheet(destination: .apariencia)
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .estudiante, careerId: "ingenieria-sistemas"))))
}

#Preview("Seguridad") {
    CuentaDestinationSheet(destination: .seguridad)
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .estudiante, careerId: "ingenieria-sistemas"))))
}
