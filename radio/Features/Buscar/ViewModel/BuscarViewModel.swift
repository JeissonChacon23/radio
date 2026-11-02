// radio/Features/Buscar/ViewModel/BuscarViewModel.swift

import Foundation
import Observation

@MainActor
@Observable
final class BuscarViewModel {
    var query = ""

    private(set) var results = SearchResults()
    private(set) var isSearching = false
    private(set) var hasSearched = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let service = BuscarService()
    @ObservationIgnored private let podcastService = PodcastService()
    @ObservationIgnored private var catalog: SearchCatalog?
    @ObservationIgnored private var catalogKey = ""
    @ObservationIgnored private var catalogLoadedAt = Date.distantPast

    init() {}

    #if DEBUG
    /// Only for SwiftUI previews.
    init(previewResults: SearchResults, query: String = "radio") {
        self.results = previewResults
        self.query = query
        self.hasSearched = true
    }
    #endif

    func search(audienceTags: [String]) async {
        let terms = Self.terms(from: query)
        guard !terms.isEmpty else {
            results = SearchResults()
            hasSearched = false
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let catalog = try await loadCatalog(audienceTags: audienceTags)

            let programHits = catalog.programs
                .compactMap { programa -> ProgramHit? in
                    let matches = Self.matches(in: [programa.name, programa.collective] + programa.hosts, terms: terms)
                    return matches > 0 ? ProgramHit(programa: programa, matches: matches) : nil
                }
                .sorted { ($0.matches, $1.programa.name) > ($1.matches, $0.programa.name) }

            let eventHits = catalog.events
                .compactMap { event -> EventHit? in
                    let matches = Self.matches(in: [event.title, event.description], terms: terms)
                    return matches > 0 ? EventHit(event: event, matches: matches) : nil
                }
                .sorted { ($0.matches, $0.event.date) > ($1.matches, $1.event.date) }

            // The podcast part must not break the rest of the results if it fails.
            var podcastHits: [String: PodcastHit] = [:]
            do {
                for hit in try await podcastService.episodes(matching: terms) {
                    podcastHits[hit.episode.id] = PodcastHit(episode: hit.episode, matches: hit.matches)
                }

                // Episodes of the programs whose name matched also count.
                let programMatches = Dictionary(uniqueKeysWithValues: programHits.map { ($0.programa.id, $0.matches) })
                for episode in try await podcastService.episodes(programIds: Array(programMatches.keys)) {
                    let bonus = programMatches[episode.programId] ?? 0
                    let previous = podcastHits[episode.id]?.matches ?? 0
                    podcastHits[episode.id] = PodcastHit(episode: episode, matches: previous + bonus)
                }
            } catch {
                // If Firestore asks for an index, this message includes the link to create it.
                print("BuscarViewModel: podcast search failed:", error)
            }

            results = SearchResults(
                programs: programHits,
                events: eventHits,
                podcasts: podcastHits.values.sorted { ($0.matches, $0.episode.airDate) > ($1.matches, $1.episode.airDate) }
            )
            hasSearched = true
        } catch {
            print("BuscarViewModel.search failed:", error)
            errorMessage = "No se pudo realizar la búsqueda. Inténtalo de nuevo."
        }
    }

    /// Programs and events are loaded once and reused for a few minutes.
    private func loadCatalog(audienceTags: [String]) async throws -> SearchCatalog {
        let key = audienceTags.joined(separator: ",")
        if let catalog, key == catalogKey, Date().timeIntervalSince(catalogLoadedAt) < 300 {
            return catalog
        }
        let fresh = try await service.loadCatalog(audienceTags: audienceTags)
        catalog = fresh
        catalogKey = key
        catalogLoadedAt = .now
        return fresh
    }

    private nonisolated static func matches(in texts: [String], terms: [String]) -> Int {
        let haystack = texts
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return terms.filter { haystack.contains($0) }.count
    }

    /// Same normalization as the transcriber: lowercase, no accents, words of 3+ letters.
    /// Firestore accepts at most 30 values in arrayContainsAny.
    nonisolated static func terms(from text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var seen = Set<String>()
        return Array(words.filter { seen.insert($0).inserted }.prefix(30))
    }
}
