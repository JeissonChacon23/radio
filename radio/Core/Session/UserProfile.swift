// radio/Core/Session/UserProfile.swift

//
//  UserProfile.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import Foundation

enum ProfileType: String, CaseIterable, Identifiable {
    case estudiante
    case egresado
    case personalUFPS = "personal_ufps"
    case invitado

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estudiante: "Estudiante"
        case .egresado: "Egresado"
        case .personalUFPS: "Personal UFPS (docente o administrativo)"
        case .invitado: "Invitado / comunidad en general"
        }
    }
}

struct Career: Identifiable, Hashable {
    let id: String
    let name: String
    let faculty: String
    let campus: String    // "cucuta" or "ocana"
    let modality: String  // "presencial" or "distancia"

    var group: String { campus == "ocana" ? "Ocaña · \(faculty)" : faculty }
}

struct UserProfile: Equatable {
    let profileType: ProfileType
    let careerId: String?

    /// Values compared against events.audience (arrayContainsAny allows up to 30).
    var audienceTags: [String] {
        var tags = ["todos", profileType.rawValue]
        if let careerId { tags.append(careerId) }
        return tags
    }
}
