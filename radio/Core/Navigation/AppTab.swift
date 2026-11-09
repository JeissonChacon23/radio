// radio/Core/Navigation/AppTab.swift

import SwiftUI

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case inicio
    case calendario
    case podcast
    case buscar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inicio: "Inicio"
        case .calendario: "Calendario"
        case .podcast: "Podcast"
        case .buscar: "Buscar"
        }
    }

    var systemImage: String {
        switch self {
        case .inicio: "house.fill"
        case .calendario: "calendar"
        case .podcast: "headphones"
        case .buscar: "magnifyingglass"
        }
    }
}
