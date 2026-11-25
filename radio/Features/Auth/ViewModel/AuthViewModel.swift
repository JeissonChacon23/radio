// radio/Features/Auth/ViewModel/AuthViewModel.swift

import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Iniciar sesión"
        case signUp = "Crear cuenta"

        var id: String { rawValue }
    }

    var mode: Mode = .signIn {
        didSet {
            errorMessage = nil
            infoMessage = nil
        }
    }
    var firstName = ""
    var lastName = ""
    var phone = "" {
        didSet {
            let digits = String(phone.filter(\.isNumber).prefix(15))
            if digits != phone { phone = digits }
        }
    }
    var email = ""
    var password = ""
    var confirmPassword = ""
    var errorMessage: String?
    var infoMessage: String?

    private(set) var isWorking = false

    private var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPhone: String {
        phone.filter(\.isNumber)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValidEmail: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".")
    }

    var passwordsMismatch: Bool {
        mode == .signUp && !confirmPassword.isEmpty && password != confirmPassword
    }

    var canSubmit: Bool {
        guard isValidEmail, password.count >= 6 else { return false }
        if mode == .signUp {
            return !trimmedFirstName.isEmpty
                && !trimmedLastName.isEmpty
                && trimmedPhone.count >= 7
                && password == confirmPassword
        }
        return true
    }

    func submit(using session: SessionStore) async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        defer { isWorking = false }
        do {
            switch mode {
            case .signIn:
                try await session.signIn(email: trimmedEmail, password: password)
            case .signUp:
                try await session.signUp(
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    phone: trimmedPhone,
                    email: trimmedEmail,
                    password: password
                )
            }
        } catch {
            errorMessage = AuthErrorMessage.text(for: error)
        }
    }

    func resetPassword(using session: SessionStore) async {
        guard isValidEmail else {
            errorMessage = "Escribe tu correo para enviarte el enlace."
            return
        }
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        defer { isWorking = false }
        do {
            try await session.sendPasswordReset(email: trimmedEmail)
            infoMessage = "Si existe una cuenta con ese correo, te enviamos un enlace para restablecer la contraseña."
        } catch {
            errorMessage = AuthErrorMessage.text(for: error)
        }
    }
}
