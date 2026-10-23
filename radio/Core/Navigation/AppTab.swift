// radio/Core/Navigation/AppTab.swift

// Radio/Core/Navigation/AppTab.swift

import SwiftUI

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case inicio
    case programacion
    case calendario
    case buscar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inicio: "Inicio"
        case .programacion: "Programación"
        case .calendario: "Calendario"
        case .buscar: "Buscar"
        }
    }

    var systemImage: String {
        switch self {
        case .inicio: "house.fill"
        case .programacion: "calendar.day.timeline.leading"
        case .calendario: "calendar"
        case .buscar: "magnifyingglass"
        }
    }
}

