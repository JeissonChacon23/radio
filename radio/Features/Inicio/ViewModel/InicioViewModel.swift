// radio/Features/Inicio/ViewModel/InicioViewModel.swift

//
//  InicioViewModel.swift
//  radio
//
//  Created by Foster Chacon on 23/10/26.
//

// InicioViewModel.swift

import Observation

@MainActor
@Observable
final class InicioViewModel {
    var player: RadioPlayerManager { RadioPlayerManager.shared }

    func togglePlayback() {
        player.togglePlayback()
    }
}
