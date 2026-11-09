// radio/Core/Support/DriveAudio.swift

import Foundation

enum DriveAudio {
    /// Google does not document these download URLs as an API, so several are tried in order.
    nonisolated static func candidates(id: String) -> [URL] {
        [
            "https://drive.usercontent.google.com/download?id=\(id)&export=download&confirm=t",
            "https://drive.google.com/uc?export=download&id=\(id)"
        ].compactMap { URL(string: $0) }
    }
}
