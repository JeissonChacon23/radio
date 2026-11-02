// radio/Core/Audio/AudioFocus.swift

import Foundation

enum AudioSource {
    case radio
    case podcast
}

/// Only one thing plays at a time: whoever starts takes the focus and the other one stops.
@MainActor
enum AudioFocus {
    private(set) static var current: AudioSource?
    private static var stoppers: [AudioSource: () -> Void] = [:]

    static func register(_ source: AudioSource, stop: @escaping () -> Void) {
        stoppers[source] = stop
    }

    static func claim(_ source: AudioSource) {
        if let current, current != source {
            stoppers[current]?()
        }
        current = source
    }

    static func release(_ source: AudioSource) {
        if current == source { current = nil }
    }

    static func stopAll() {
        for stop in stoppers.values { stop() }
    }
}
