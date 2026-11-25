// radio/Features/Podcast/View/PodcastRow.swift

import SwiftUI

struct PodcastRow: View {
    let episode: PodcastEpisode
    var isStarred: Bool = false
    var onToggleStar: (() -> Void)? = nil
    var matchedSnippet: String? = nil
    var matchedStartSeconds: Double? = nil
    var searchTerms: [String] = []
    var onViewTranscript: (() -> Void)? = nil

    @Environment(PodcastPlayerManager.self) private var player

    private var isCurrent: Bool { player.current?.id == episode.id }
    private var isPlayingCurrent: Bool { isCurrent && player.isPlaying }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                DriveArtworkView(id: episode.imageId, cornerRadius: 12, pixelSize: 1024)
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.black.opacity(0.10), radius: 5, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    if isCurrent {
                        HStack(spacing: 4) {
                            Image(systemName: isPlayingCurrent ? "waveform" : "pause.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                            Text(isPlayingCurrent ? "REPRODUCIENDO" : "EN PAUSA")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color.ufpsRed, Color.ufpsCrimson],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                    }

                    Text(episode.programName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(Color.ufpsRed)
                        Text(episode.dateAndTimeText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !episode.hosts.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.ufpsRed)
                            Text(episode.hosts.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    if let onToggleStar {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                                onToggleStar()
                            }
                        } label: {
                            Image(systemName: isStarred ? "star.fill" : "star")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isStarred ? Color.ufpsRed : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 36, height: 36)
                                .background(
                                    Color(.tertiarySystemFill),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isStarred ? "Quitar podcast de destacados" : "Destacar podcast")
                    }

                    // Botón circular de reproducción/pausa con identidad UFPS
                    ZStack {
                        if isCurrent {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.ufpsRed, Color.ufpsCrimson],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.ufpsRed.opacity(0.30), radius: 6, y: 3)
                        } else {
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                        }

                        if isCurrent && player.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isPlayingCurrent ? "pause.fill" : "play.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(isCurrent ? Color.white : Color.ufpsRed)
                                .contentTransition(.symbolEffect(.replace))
                                .offset(x: isPlayingCurrent ? 0 : 1)
                        }
                    }
                    .frame(width: 40, height: 40)
                }
            }

            if let matchedSnippet, !matchedSnippet.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "quote.opening")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.ufpsRed)
                        Text("Fragmento donde se habló del tema")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let matchedStartSeconds {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.ufpsRed)
                                Text("Desde \(Self.formatTime(matchedStartSeconds))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                        }
                    }

                    Text(Self.highlightedText(matchedSnippet, terms: searchTerms))
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(4)

                    if let onViewTranscript {
                        Divider()

                        Button {
                            onViewTranscript()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.ufpsRed)
                                Text("Ver transcripción completa en este punto")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
        .contentShape(Rectangle())
    }

    static func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Resalta en negrita las palabras que coinciden con la búsqueda dentro del fragmento.
    static func highlightedText(_ rawText: String, terms: [String]) -> AttributedString {
        guard !terms.isEmpty else { return AttributedString(rawText) }
        let words = rawText.split(whereSeparator: \.isWhitespace).map(String.init)
        var result = AttributedString()

        for (idx, word) in words.enumerated() {
            if idx > 0 {
                result.append(AttributedString(" "))
            }
            let normalizedWord = word
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .lowercased()
                .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

            let isMatch = terms.contains { term in
                normalizedWord == term || (term.count >= 4 && normalizedWord.hasPrefix(term))
            }

            var part = AttributedString(word)
            if isMatch {
                part.inlinePresentationIntent = .stronglyEmphasized
                part.underlineStyle = .single
            }
            result.append(part)
        }
        return result
    }
}

#Preview {
    PodcastRow(
        episode: PodcastEpisode(
            id: "1",
            programId: "p1",
            programName: "Artistas UFPS Radio",
            airDate: .now,
            airTime: "10:00",
            hosts: ["Ana", "Luis"],
            imageId: nil,
            audioId: "x"
        ),
        isStarred: true,
        onToggleStar: {},
        matchedSnippet: "…estuvimos conversando sobre la calidad de audio y los proyectos de ingeniería…",
        matchedStartSeconds: 252,
        searchTerms: ["calidad", "audio"]
    )
    .padding()
    .environment(PodcastPlayerManager())
}
