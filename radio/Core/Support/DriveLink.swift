// radio/Core/Support/DriveLink.swift

import Foundation

enum DriveLink {
    nonisolated(unsafe) private static let extractionRegexes: [NSRegularExpression] = [
        #"/file/d/([A-Za-z0-9_-]{10,})"#,
        #"[?&]id=([A-Za-z0-9_-]{10,})"#,
        #"/d/([A-Za-z0-9_-]{10,})"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    nonisolated(unsafe) private static let bareIdRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[A-Za-z0-9_-]{20,}$"#
    )

    /// Accepts a Drive share link or a bare file ID (the web saves the ID).
    nonisolated static func fileId(from text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let fullRange = NSRange(value.startIndex..., in: value)
        for regex in extractionRegexes {
            if let match = regex.firstMatch(in: value, range: fullRange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: value) {
                return String(value[range])
            }
        }

        if let bareIdRegex, bareIdRegex.firstMatch(in: value, range: fullRange) != nil {
            return value
        }
        return nil
    }
}
