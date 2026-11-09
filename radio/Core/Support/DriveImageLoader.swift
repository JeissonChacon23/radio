//
//  DriveImageLoader.swift
//  radio
//
//  Created by Foster Chacon on 28/10/26.
//

// radio/Core/Support/DriveImageLoader.swift

import Foundation

/// Google does not document these image URLs as an API, so several are tried in order.
/// The order is the same one the web admin uses.
enum DriveImageLoader {
    nonisolated static func candidates(id: String, size: Int) -> [URL] {
        [
            "https://drive.google.com/thumbnail?id=\(id)&sz=w\(size)",
            "https://lh3.googleusercontent.com/d/\(id)=w\(size)",
            "https://drive.google.com/uc?export=view&id=\(id)"
        ].compactMap { URL(string: $0) }
    }

    /// Returns the data of the first response that is a real image, or nil.
    nonisolated static func loadData(id: String, size: Int = 1024) async -> Data? {
        for url in candidates(id: id, size: size) {
            guard !Task.isCancelled else { return nil }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      http.mimeType?.hasPrefix("image/") == true else { continue }
                return data
            } catch {
                continue
            }
        }
        return nil
    }
}
