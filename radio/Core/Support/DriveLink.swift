//
//  DriveLink.swift
//  radio
//
//  Created by Foster Chacon on 29/10/26.
//

// radio/Core/Support/DriveLink.swift

import Foundation

enum DriveLink {
    /// Accepts a Drive share link or a bare file ID (the web saves the ID).
    nonisolated static func fileId(from text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let patterns = [
            #"/file/d/([A-Za-z0-9_-]{10,})"#,
            #"[?&]id=([A-Za-z0-9_-]{10,})"#,
            #"/d/([A-Za-z0-9_-]{10,})"#
        ]
        for pattern in patterns {
            if let id = firstCapture(pattern, in: value) { return id }
        }
        return value.range(of: #"^[A-Za-z0-9_-]{20,}$"#, options: .regularExpression) != nil ? value : nil
    }

    private nonisolated static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
