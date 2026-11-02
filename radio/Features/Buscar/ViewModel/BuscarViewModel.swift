// radio/Features/Buscar/ViewMode/BuscarViewModel.swift

//
//  BuscarViewModel.swift
//  radio
//
//  Created by Foster Chacon on 23/10/26.
//

// UFPSRadio/Features/Buscar/ViewModel/BuscarViewModel.swift

import Observation

@MainActor
@Observable
final class BuscarViewModel {
    var resultados: [String] = []

    func buscar(_ query: String) {
        // TODO: Filtrar programas/episodios según query
        guard !query.isEmpty else {
            resultados = []
            return
        }
    }
}
