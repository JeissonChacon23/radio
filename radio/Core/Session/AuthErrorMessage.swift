// radio/Core/Session/AuthErrorMessage.swift

//
//  AuthErrorMessage.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import Foundation
import FirebaseAuth

enum AuthErrorMessage {
    // Firebase Auth error codes (same numbers across SDK versions).
    private enum Code {
        static let invalidCredential = 17004
        static let userDisabled = 17005
        static let operationNotAllowed = 17006
        static let emailAlreadyInUse = 17007
        static let invalidEmail = 17008
        static let wrongPassword = 17009
        static let tooManyRequests = 17010
        static let userNotFound = 17011
        static let requiresRecentLogin = 17014
        static let networkError = 17020
        static let invalidAPIKey = 17023
        static let weakPassword = 17026
    }

    static func text(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return "Ocurrió un error inesperado. Inténtalo de nuevo."
        }

        switch nsError.code {
        case Code.invalidEmail:
            return "El correo no tiene un formato válido."
        case Code.emailAlreadyInUse:
            return "Ya existe una cuenta con ese correo."
        case Code.weakPassword:
            return "La contraseña es muy débil. Usa al menos 6 caracteres."
        case Code.wrongPassword, Code.userNotFound, Code.invalidCredential:
            return "Correo o contraseña incorrectos."
        case Code.userDisabled:
            return "Esta cuenta está deshabilitada."
        case Code.networkError:
            return "Sin conexión. Revisa tu internet."
        case Code.tooManyRequests:
            return "Demasiados intentos. Espera un momento e inténtalo de nuevo."
        case Code.operationNotAllowed:
            return "El acceso con correo no está activado en Firebase."
        case Code.requiresRecentLogin:
            return "Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo."
        case Code.invalidAPIKey:
            return "La configuración de Firebase no es válida. Revisa el GoogleService-Info.plist."
        default:
            return "No se pudo completar la operación (código \(nsError.code))."
        }
    }
}
