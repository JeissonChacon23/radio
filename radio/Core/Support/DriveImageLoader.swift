// radio/Core/Support/DriveImageLoader.swift

import Foundation

/// Loads full-resolution artwork from Google Drive, prioritizing the original file
/// endpoints over compressed thumbnail endpoints.
enum DriveImageLoader {
    nonisolated(unsafe) private static let cache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 120
        cache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
        return cache
    }()

    nonisolated static func candidates(id: String) -> [URL] {
        [
            "https://drive.usercontent.google.com/download?id=\(id)&export=view",
            "https://drive.google.com/uc?export=view&id=\(id)",
            "https://lh3.googleusercontent.com/d/\(id)=s2048",
            "https://drive.google.com/thumbnail?id=\(id)&sz=w2048"
        ].compactMap { URL(string: $0) }
    }

    /// Returns cached full-resolution image data if available, otherwise downloads from the first working candidate URL.
    nonisolated static func loadData(id: String, size: Int = 1024) async -> Data? {
        let cacheKey = id as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached as Data
        }

        for url in candidates(id: id) {
            guard !Task.isCancelled else { return nil }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      http.mimeType?.hasPrefix("image/") == true,
                      !data.isEmpty else { continue }
                cache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
                return data
            } catch {
                continue
            }
        }
        return nil
    }
}
