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

    /// I5: Spanish stopwords (normalized without accents) ignored before searching.
    nonisolated static let stopwords: Set<String> = [
        "a", "al", "algo", "algun", "alguna", "algunas", "alguno", "algunos", "ante", "antes",
        "aqui", "asi", "aun", "aunque", "bien", "bueno", "cada", "casi", "como", "con", "contra",
        "cosa", "cosas", "cual", "cuales", "cuando", "cuanto", "de", "del", "desde", "donde",
        "dos", "el", "ella", "ellas", "ello", "ellos", "en", "entonces", "entre", "era", "eran",
        "eres", "es", "esa", "esas", "ese", "eso", "esos", "esta", "estaba", "estaban", "estamos",
        "estan", "estar", "este", "esto", "estos", "estoy", "fue", "fueron", "fui", "ha", "haber",
        "habia", "hace", "hacer", "hacia", "han", "hasta", "hay", "he", "hemos", "hoy", "la",
        "las", "le", "les", "lo", "los", "mas", "me", "mi", "mientras", "mis", "mismo", "muchas",
        "mucho", "muchos", "muy", "nada", "ni", "no", "nos", "nosotros", "nuestra", "nuestro",
        "o", "osea", "otra", "otras", "otro", "otros", "para", "pero", "poco", "pues", "por",
        "porque", "que", "quien", "quienes", "se", "sea", "segun", "ser", "si", "siempre", "sin",
        "sobre", "solo", "son", "soy", "su", "sus", "tambien", "tan", "tanto", "te", "tener",
        "tengo", "ti", "tiene", "tienen", "todo", "toda", "todos", "todas", "tu", "tus", "un",
        "una", "uno", "unos", "unas", "usted", "ustedes", "va", "vamos", "van", "veces", "vez",
        "voy", "y", "ya", "yo"
    ]

    init() {}

    #if DEBUG
    /// Only for SwiftUI previews.
    init(previewResults: SearchResults, query: String = "radio") {
        self.results = previewResults
        self.query = query
        self.hasSearched = true
    }
    #endif

    func search(profile: UserProfile?) async {
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
            let catalog = try await loadCatalog(profile: profile)

            let programHits = catalog.programs
                .compactMap { programa -> ProgramHit? in
                    let matches = Self.matches(
                        in: [programa.name, programa.collective] + programa.hosts,
                        terms: terms
                    )
                    return matches > 0 ? ProgramHit(programa: programa, matches: matches) : nil
                }
                .sorted { ($0.matches, $1.programa.name) > ($1.matches, $0.programa.name) }

            let eventHits = catalog.events
                .compactMap { event -> EventHit? in
                    let matches = Self.matches(
                        in: [event.title, event.description, event.specialGuest],
                        terms: terms
                    )
                    return matches > 0 ? EventHit(event: event, matches: matches) : nil
                }
                .sorted { ($0.matches, $0.event.date) > ($1.matches, $1.event.date) }

            var podcastHits: [PodcastHit] = []
            do {
                podcastHits = try await podcastService.episodes(matching: terms)
                    .map { PodcastHit(episode: $0.episode, matches: $0.matches) }
                    .sorted { ($0.matches, $0.episode.airDate) > ($1.matches, $1.episode.airDate) }
            } catch {
                print("BuscarViewModel: podcast search failed:", error)
            }

            results = SearchResults(
                programs: programHits,
                events: eventHits,
                podcasts: podcastHits
            )
            hasSearched = true
        } catch {
            print("BuscarViewModel.search failed:", error)
            errorMessage = "No se pudo realizar la búsqueda. Inténtalo de nuevo."
        }
    }

    private func loadCatalog(profile: UserProfile?) async throws -> SearchCatalog {
        let key = profile?.audienceTags.joined(separator: ",") ?? "invitado"
        if let catalog, key == catalogKey, Date().timeIntervalSince(catalogLoadedAt) < 120 {
            return catalog
        }
        let fresh = try await service.loadCatalog(profile: profile)
        catalog = fresh
        catalogKey = key
        catalogLoadedAt = .now
        return fresh
    }

    /// I6 & I7: Tokenizes haystack without accents and checks that ALL meaningful terms match
    /// as whole words or word prefixes (4+ chars), preventing unrelated partial matches.
    nonisolated static func matches(in texts: [String], terms: [String]) -> Int {
        guard !terms.isEmpty else { return 0 }
        let folded = texts
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
        let tokens = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return 0 }

        var matchedTerms = 0
        var totalOccurrences = 0

        for term in terms {
            let hits = tokens.filter { token in
                if token == term { return true }
                if term.count >= 4 && token.hasPrefix(term) { return true }
                return false
            }.count
            if hits > 0 {
                matchedTerms += 1
                totalOccurrences += hits
            }
        }

        // Require all searched terms to be present in the item to avoid unrelated noise (I7).
        guard matchedTerms == terms.count else { return 0 }
        return totalOccurrences
    }

    /// I5: Lowercase, no accents, removes Spanish stopwords.
    nonisolated static func terms(from text: String) -> [String] {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 && !stopwords.contains($0) }

        var seen = Set<String>()
        return Array(words.filter { seen.insert($0).inserted }.prefix(20))
    }
}
