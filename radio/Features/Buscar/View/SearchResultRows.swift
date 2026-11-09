// radio/Features/Buscar/View/SearchResultRows.swift

import SwiftUI

struct ProgramHitRow: View {
    let programa: Programa

    private var days: String {
        DiaSemana.all.filter { programa.days.contains($0.id) }.map(\.short).joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            DriveArtworkView(id: programa.artworkId, cornerRadius: 10, pixelSize: 256)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(programa.name)
                    .font(.headline)
                Text("\(days) · \(programa.timeRangeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !programa.hosts.isEmpty {
                    Text(programa.hosts.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EventHitRow: View {
    let event: EventItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)
            Label(event.dateRangeText, systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !event.specialGuest.isEmpty {
                Label("Invitado: \(event.specialGuest)", systemImage: "person.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
            if !event.description.isEmpty {
                Text(event.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EventHitDetailView: View {
    let event: EventItem
    @State private var showingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title)
                    .font(.title2.bold())

                Label(event.dateRangeText, systemImage: "calendar.badge.clock")
                    .foregroundStyle(.secondary)

                if !event.specialGuest.isEmpty {
                    Label("Invitado especial: \(event.specialGuest)", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }

                if !event.description.isEmpty {
                    Divider()
                    Text(event.description)
                }

                if event.link != nil {
                    Button {
                        showingSafari = true
                    } label: {
                        Label("Ver fuente", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Detalle del evento")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSafari) {
            if let link = event.link {
                SafariWebView(url: link)
                    .ignoresSafeArea()
            }
        }
    }
}
