// radio/Core/Session/UserProfile.swift

import Foundation

enum ProfileType: String, CaseIterable, Identifiable {
    case estudiante
    case egresado
    case docente
    case administrativo
    case invitado
    case externo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estudiante: "Estudiante"
        case .egresado: "Egresado"
        case .docente: "Docente"
        case .administrativo: "Administrativo"
        case .invitado: "Invitado"
        case .externo: "Externo"
        }
    }

    /// Estudiantes y egresados tienen carrera/programa; docentes departamento; administrativos, invitados y externos ninguno.
    var requiresProgram: Bool {
        self == .estudiante || self == .egresado
    }

    var requiresStudentCode: Bool {
        self == .estudiante
    }

    var requiresDepartment: Bool {
        self == .docente
    }

    static func fromFirestore(_ raw: String) -> ProfileType? {
        if raw == "personal_ufps" { return .docente }
        return ProfileType(rawValue: raw)
    }
}

struct Career: Identifiable, Hashable {
    let id: String
    let code: String              // 3-digit UFPS program code (e.g. "115" for Ingeniería de Sistemas)
    let alternateCodes: [String]
    let name: String
    let faculty: String
    let department: String
    let departmentId: String
    let level: String             // "pregrado" or "posgrado"
    let campus: String            // "cucuta" or "ocana"
    let modality: String          // "presencial" or "distancia"

    init(
        id: String,
        code: String? = nil,
        alternateCodes: [String] = [],
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
        let resolvedCode = (code?.isEmpty == false ? code! : Self.defaultCode(for: id))
        let resolvedAlt = alternateCodes.isEmpty ? Self.defaultAlternateCodes(for: id) : alternateCodes
        self.id = id
        self.code = resolvedCode
        self.alternateCodes = resolvedAlt
        self.name = name
        self.faculty = faculty
        self.department = resolvedDept
        self.departmentId = resolvedDeptId
        self.level = level
        self.campus = campus
        self.modality = modality
    }

    var group: String { campus == "ocana" ? "Ocaña · \(faculty)" : faculty }

    /// Checks whether the first 3 digits of a student code match this career's 3-digit code.
    func matches(codePrefix: String) -> Bool {
        let digits = codePrefix.filter(\.isNumber)
        guard digits.count >= 3 else { return false }
        let prefix = String(digits.prefix(3))
        return code == prefix || alternateCodes.contains(prefix)
    }

    static func findCareer(forStudentCode studentCode: String, in careers: [Career]) -> Career? {
        let digits = studentCode.filter(\.isNumber)
        guard digits.count >= 3 else { return nil }
        let prefix = String(digits.prefix(3))
        return careers.first { $0.code == prefix || $0.alternateCodes.contains(prefix) }
    }

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

    static func defaultCode(for id: String) -> String {
        fallbackCodesByCareerId[id] ?? ""
    }

    static func defaultAlternateCodes(for id: String) -> [String] {
        fallbackAlternateCodesByCareerId[id] ?? []
    }

    /// Removes leading "Departamento de " / "Departamento del " / "Departamento " so it is not repeated under a "Departamento" label.
    static func cleanDepartmentName(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["Departamento de ", "Departamento del ", "Departamento "]
        for prefix in prefixes {
            if result.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil {
                result.removeFirst(prefix.count)
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func defaultDepartment(for id: String, faculty: String, campus: String) -> String {
        if let mapped = fallbackDepartmentsByCareerId[id] {
            return mapped
        }
        let clean = faculty.replacingOccurrences(of: "Facultad de ", with: "")
        return campus == "ocana" ? "Departamento de \(clean) (Ocaña)" : "Departamento de \(clean)"
    }

    private static let fallbackCodesByCareerId: [String: String] = [
        "ingenieria-sistemas": "115",
        "tecnologia-analitica-datos": "215",
        "maestria-ingenieria-sistemas": "216",
        "ingenieria-civil": "111",
        "tecnologia-obras-civiles": "192",
        "ingenieria-industrial": "119",
        "tecnologia-procesos-industriales": "198",
        "tecnologia-gestion-procesos-manufactura": "199",
        "tecnologia-productos-ceramicos": "190",
        "ingenieria-mecanica": "112",
        "ingenieria-electromecanica": "109",
        "ingenieria-electronica": "116",
        "ingenieria-minas": "118",
        "arquitectura": "150",
        "derecho": "135",
        "comunicacion-social": "133",
        "trabajo-social": "134",
        "licenciatura-educacion-infantil": "170",
        "licenciatura-ciencias-naturales": "137",
        "maestria-practica-pedagogica": "237",
        "ingenieria-biotecnologica": "161",
        "ingenieria-ambiental": "165",
        "ingenieria-agronomica": "162",
        "zootecnia": "168",
        "ingenieria-agroindustrial": "164",
        "tecnologia-agroindustrial": "194",
        "quimica-industrial": "195",
        "licenciatura-matematicas": "136",
        "administracion-empresas": "121",
        "comercio-internacional": "126",
        "maestria-gerencia-empresas": "221",
        "contaduria-publica": "122",
        "enfermeria": "180",
        "seguridad-salud-trabajo": "181",
        "licenciatura-educacion-comunitaria": "171",
        "tecnologia-comercial-financiera": "146",
        "tecnologia-regencia-farmacia": "148",
        "tecnologia-construcciones-civiles": "142",
        "ingenieria-civil-ocana": "311",
        "ingenieria-mecanica-ocana": "312",
        "ingenieria-sistemas-ocana": "315",
        "ingenieria-industrial-ocana": "319",
        "zootecnia-ocana": "368",
        "ingenieria-ambiental-ocana": "365",
        "administracion-empresas-ocana": "321",
        "contaduria-publica-diurna-ocana": "322",
        "contaduria-publica-nocturna-ocana": "323",
        "tecnologia-gestion-comercial-financiera-ocana": "346",
        "derecho-diurno-ocana": "335",
        "derecho-nocturno-ocana": "336",
        "comunicacion-social-ocana": "333"
    ]

    private static let fallbackAlternateCodesByCareerId: [String: [String]] = [
        "ingenieria-minas": ["113"],
        "zootecnia": ["163"],
        "ingenieria-agroindustrial": ["197"],
        "tecnologia-agroindustrial": ["166", "167"],
        "quimica-industrial": ["193"],
        "licenciatura-matematicas": ["191"],
        "administracion-empresas": ["124", "125"],
        "contaduria-publica": ["123"],
        "tecnologia-comercial-financiera": ["141", "143", "145", "149"]
    ]

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
    let firstName: String
    let lastName: String
    let name: String
    let phone: String?
    let studentCode: String?
    let programCode: String?
    let profileType: ProfileType
    let careerId: String?
    let careerName: String?
    let departmentId: String?
    let department: String?
    let faculty: String?

    init(
        firstName: String = "",
        lastName: String = "",
        name: String = "",
        phone: String? = nil,
        studentCode: String? = nil,
        programCode: String? = nil,
        profileType: ProfileType,
        careerId: String?,
        careerName: String? = nil,
        departmentId: String? = nil,
        department: String? = nil,
        faculty: String? = nil
    ) {
        let cleanFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = [cleanFirst, cleanLast].filter { !$0.isEmpty }.joined(separator: " ")
        self.firstName = cleanFirst
        self.lastName = cleanLast
        self.name = combined.isEmpty ? name : combined
        self.phone = phone
        self.studentCode = studentCode
        self.programCode = programCode
        self.profileType = profileType
        self.careerId = careerId
        self.careerName = careerName
        self.departmentId = departmentId
        self.department = department
        self.faculty = faculty
    }

    /// Returns only the first given name and first surname (e.g. "Jeisson Chacón").
    var shortName: String {
        let firstWord = firstName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lastWord = lastName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        if !firstWord.isEmpty && !lastWord.isEmpty {
            return "\(firstWord) \(lastWord)"
        }
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count >= 3 {
            // E.g. "Juan Carlos Perez Gomez" -> "Juan Perez"
            let first = words[0]
            let surnameIdx = words.count == 3 ? 1 : 2
            return "\(first) \(words[surnameIdx])"
        }
        if words.count == 2 {
            return "\(words[0]) \(words[1])"
        }
        return words.first ?? name
    }

    private static let knownProfileIds: Set<String> = [
        "todos", "estudiante", "egresado", "docente", "administrativo", "invitado", "externo", "personal_ufps"
    ]

    /// Values compared against events.audience in Firestore (arrayContainsAny allows up to 30).
    var audienceTags: [String] {
        var tags = ["todos", profileType.rawValue]
        if profileType == .docente || profileType == .administrativo {
            tags.append("personal_ufps")
        }
        if profileType == .externo {
            tags.append("invitado")
        }
        if let careerId, !careerId.isEmpty { tags.append(careerId) }
        if let departmentId, !departmentId.isEmpty, !tags.contains(departmentId) {
            tags.append(departmentId)
        }
        return tags
    }

    nonisolated func matches(eventAudience: [String]) -> Bool {
        if eventAudience.contains("todos") { return true }

        let eventProfiles = eventAudience.filter { Self.knownProfileIds.contains($0) }
        let deptTags = eventAudience.filter { $0.hasPrefix("dept:") }
        let programTags = eventAudience.filter { !Self.knownProfileIds.contains($0) && !$0.hasPrefix("dept:") }

        let matchesProfileTag: Bool = {
            if eventProfiles.contains(profileType.rawValue) { return true }
            if (profileType == .docente || profileType == .administrativo) && eventProfiles.contains("personal_ufps") {
                return true
            }
            if profileType == .externo && eventProfiles.contains("invitado") {
                return true
            }
            return false
        }()

        if !eventProfiles.isEmpty && !matchesProfileTag {
            return false
        }

        switch profileType {
        case .invitado, .externo, .administrativo:
            return matchesProfileTag
        case .docente:
            if !deptTags.isEmpty {
                guard let departmentId else { return false }
                return deptTags.contains(departmentId)
            }
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
