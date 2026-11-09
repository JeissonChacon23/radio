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
        case .personalUFPS: "Docente / Personal UFPS"
        case .invitado: "Invitado / comunidad en general"
        }
    }

    /// Estudiantes y egresados eligen programa; docentes eligen departamento; invitados ninguno.
    var requiresProgram: Bool {
        self == .estudiante || self == .egresado
    }

    var requiresDepartment: Bool {
        self == .personalUFPS
    }
}

struct Career: Identifiable, Hashable {
    let id: String
    let name: String
    let faculty: String
    let department: String
    let departmentId: String
    let level: String     // "pregrado" or "posgrado"
    let campus: String    // "cucuta" or "ocana"
    let modality: String  // "presencial" or "distancia"

    init(
        id: String,
        name: String,
        faculty: String,
        department: String? = nil,
        departmentId: String? = nil,
        level: String = "pregrado",
        campus: String = "cucuta",
        modality: String = "presencial"
    ) {
        let resolvedDept = department ?? Self.defaultDepartment(for: id, faculty: faculty, campus: campus)
        let resolvedDeptId = departmentId ?? Self.makeDepartmentId(department: resolvedDept, campus: campus)
        self.id = id
        self.name = name
        self.faculty = faculty
        self.department = resolvedDept
        self.departmentId = resolvedDeptId
        self.level = level
        self.campus = campus
        self.modality = modality
    }

    var group: String { campus == "ocana" ? "Ocaña · \(faculty)" : faculty }

    static func makeDepartmentId(department: String, campus: String) -> String {
        let folded = department
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
        let slug = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        if campus == "ocana" && !slug.contains("ocana") {
            return "dept:\(slug)-ocana"
        }
        return "dept:\(slug)"
    }

    static func defaultDepartment(for id: String, faculty: String, campus: String) -> String {
        if let mapped = fallbackDepartmentsByCareerId[id] {
            return mapped
        }
        let clean = faculty.replacingOccurrences(of: "Facultad de ", with: "")
        return campus == "ocana" ? "Departamento de \(clean) (Ocaña)" : "Departamento de \(clean)"
    }

    private static let fallbackDepartmentsByCareerId: [String: String] = [
        "ingenieria-sistemas": "Departamento de Sistemas e Informática",
        "tecnologia-analitica-datos": "Departamento de Sistemas e Informática",
        "maestria-ingenieria-sistemas": "Departamento de Sistemas e Informática",
        "ingenieria-civil": "Departamento de Construcciones Civiles, Vías y Transporte",
        "tecnologia-obras-civiles": "Departamento de Construcciones Civiles, Vías y Transporte",
        "ingenieria-industrial": "Departamento de Procesos Industriales",
        "tecnologia-procesos-industriales": "Departamento de Procesos Industriales",
        "tecnologia-gestion-procesos-manufactura": "Departamento de Procesos Industriales",
        "tecnologia-productos-ceramicos": "Departamento de Procesos Industriales",
        "ingenieria-mecanica": "Departamento de Diseño Mecánico, Materiales y Procesos",
        "ingenieria-electromecanica": "Departamento de Diseño Mecánico, Materiales y Procesos",
        "ingenieria-electronica": "Departamento de Electricidad y Electrónica",
        "ingenieria-minas": "Departamento de Geotecnia y Minería",
        "arquitectura": "Departamento de Arquitectura, Diseño y Urbanismo",
        "derecho": "Departamento de Estudios Sociales y Humanos",
        "comunicacion-social": "Departamento de Estudios Sociales y Humanos",
        "trabajo-social": "Departamento de Estudios Sociales y Humanos",
        "licenciatura-educacion-infantil": "Departamento de Pedagogía, Andragogía, Comunicación y Multimedios",
        "licenciatura-ciencias-naturales": "Departamento de Pedagogía, Andragogía, Comunicación y Multimedios",
        "maestria-practica-pedagogica": "Departamento de Pedagogía, Andragogía, Comunicación y Multimedios",
        "ingenieria-biotecnologica": "Departamento de Ciencias del Medio Ambiente",
        "ingenieria-ambiental": "Departamento de Ciencias del Medio Ambiente",
        "ingenieria-agronomica": "Departamento de Ciencias Agrícolas y Pecuarias",
        "zootecnia": "Departamento de Ciencias Agrícolas y Pecuarias",
        "ingenieria-agroindustrial": "Departamento de Ciencias Agroindustriales",
        "tecnologia-agroindustrial": "Departamento de Ciencias Agroindustriales",
        "quimica-industrial": "Departamento de Química",
        "licenciatura-matematicas": "Departamento de Matemáticas y Estadística",
        "administracion-empresas": "Departamento de Ciencias Administrativas",
        "comercio-internacional": "Departamento de Ciencias Administrativas",
        "maestria-gerencia-empresas": "Departamento de Ciencias Administrativas",
        "contaduria-publica": "Departamento de Ciencias Contables y Financieras",
        "enfermeria": "Departamento de Enfermería",
        "seguridad-salud-trabajo": "Departamento de Seguridad y Salud en el Trabajo",
        "licenciatura-educacion-comunitaria": "Departamento de Estudios a Distancia",
        "tecnologia-comercial-financiera": "Departamento de Estudios a Distancia",
        "tecnologia-regencia-farmacia": "Departamento de Estudios a Distancia",
        "tecnologia-construcciones-civiles": "Departamento de Estudios a Distancia",
        "ingenieria-civil-ocana": "Departamento de Ingeniería Civil (Ocaña)",
        "ingenieria-mecanica-ocana": "Departamento de Ingeniería Mecánica (Ocaña)",
        "ingenieria-sistemas-ocana": "Departamento de Sistemas e Informática (Ocaña)",
        "ingenieria-industrial-ocana": "Departamento de Ingeniería Industrial (Ocaña)",
        "zootecnia-ocana": "Departamento de Ciencias Agrarias y del Ambiente (Ocaña)",
        "ingenieria-ambiental-ocana": "Departamento de Ciencias Agrarias y del Ambiente (Ocaña)",
        "administracion-empresas-ocana": "Departamento de Ciencias Administrativas (Ocaña)",
        "contaduria-publica-diurna-ocana": "Departamento de Ciencias Contables y Financieras (Ocaña)",
        "contaduria-publica-nocturna-ocana": "Departamento de Ciencias Contables y Financieras (Ocaña)",
        "tecnologia-gestion-comercial-financiera-ocana": "Departamento de Ciencias Contables y Financieras (Ocaña)",
        "derecho-diurno-ocana": "Departamento de Humanidades y Artes (Ocaña)",
        "derecho-nocturno-ocana": "Departamento de Humanidades y Artes (Ocaña)",
        "comunicacion-social-ocana": "Departamento de Humanidades y Artes (Ocaña)"
    ]
}

struct DepartmentOption: Identifiable, Hashable {
    let id: String       // departmentId ("dept:...")
    let name: String     // department name
    let faculty: String
    let campus: String

    var group: String { campus == "ocana" ? "Ocaña · \(faculty)" : faculty }
}

struct UserProfile: Equatable {
    let profileType: ProfileType
    let careerId: String?
    let departmentId: String?

    init(profileType: ProfileType, careerId: String?, departmentId: String? = nil) {
        self.profileType = profileType
        self.careerId = careerId
        self.departmentId = departmentId
    }

    private static let knownProfileIds: Set<String> = [
        "todos", "estudiante", "egresado", "personal_ufps", "invitado"
    ]

    /// Values compared against events.audience in Firestore (arrayContainsAny allows up to 30).
    var audienceTags: [String] {
        var tags = ["todos", profileType.rawValue]
        if let careerId, !careerId.isEmpty { tags.append(careerId) }
        if let departmentId, !departmentId.isEmpty, !tags.contains(departmentId) {
            tags.append(departmentId)
        }
        return tags
    }

    /// Exact client-side check for I2:
    /// - "todos" matches everyone.
    /// - If the event specifies profiles (estudiante, egresado, personal_ufps, invitado), the user's profile must be included.
    /// - If the event also specifies academic targets:
    ///   - For docentes (personal_ufps): if departments (dept:...) are listed, user's departmentId must match.
    ///   - For estudiantes/egresados: if programs are listed, user's careerId must match (or if only departments are listed, departmentId must match).
    nonisolated func matches(eventAudience: [String]) -> Bool {
        if eventAudience.contains("todos") { return true }

        let eventProfiles = eventAudience.filter { Self.knownProfileIds.contains($0) }
        let deptTags = eventAudience.filter { $0.hasPrefix("dept:") }
        let programTags = eventAudience.filter { !Self.knownProfileIds.contains($0) && !$0.hasPrefix("dept:") }

        // If the event specified profile types, the user's profile must be one of them.
        if !eventProfiles.isEmpty && !eventProfiles.contains(profileType.rawValue) {
            return false
        }

        switch profileType {
        case .invitado:
            return eventProfiles.contains("invitado")
        case .personalUFPS:
            if !deptTags.isEmpty {
                guard let departmentId else { return false }
                return deptTags.contains(departmentId)
            }
            // If an event has no profile tags and only program tags, it is not for general staff unless their careerId matches
            if eventProfiles.isEmpty && !programTags.isEmpty {
                guard let careerId else { return false }
                return programTags.contains(careerId)
            }
            return true
        case .estudiante, .egresado:
            if !programTags.isEmpty {
                guard let careerId else { return false }
                return programTags.contains(careerId)
            }
            if !deptTags.isEmpty {
                guard let departmentId else { return false }
                return deptTags.contains(departmentId)
            }
            return true
        }
    }
}
