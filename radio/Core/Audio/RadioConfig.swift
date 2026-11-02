//
//  RadioConfig.swift
//  radio
//
//  Created by Foster Chacon on 28/10/26.
//

// radio/Core/Audio/RadioConfig.swift

import Foundation

enum RadioConfig {
    /// Used when config/app.streamUrl is missing in Firestore or Firestore cannot be reached.
    /// Replace it with the URL the previous version of the app used, if it was different.
    nonisolated static let fallbackStreamURL = URL(string: "https://apps.ufps.edu.co/emisoraufps")
}
