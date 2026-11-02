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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title)
                    .font(.title2.bold())

                Label(event.dateRangeText, systemImage: "calendar")
                    .foregroundStyle(.secondary)

                if !event.description.isEmpty {
                    Text(event.description)
                }

                if let link = event.link {
                    Link(destination: link) {
                        Label("Ver fuente", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Evento")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Programa") {
    List {
        ProgramHitRow(
            programa: Programa(
                id: "1", name: "Mañanas UFPS", days: [1, 2, 3, 4, 5], startTime: "07:00",
                durationMinutes: 120, collective: "Colectivo Radio", hosts: ["Ana", "Luis"],
                artworkDriveId: ""
            )
        )
    }
}

#Preview("Evento") {
    List {
        EventHitRow(
            event: EventItem(
                id: "1", title: "Feria de emprendimiento",
                description: "Encuentro con proyectos de estudiantes y egresados.",
                date: .now, endDate: nil, link: nil
            )
        )
    }
}

#Preview("Detalle del evento") {
    NavigationStack {
        EventHitDetailView(
            event: EventItem(
                id: "1", title: "Feria de emprendimiento",
                description: "Encuentro con proyectos de estudiantes y egresados.",
                date: .now, endDate: nil, link: URL(string: "https://ufps.edu.co")
            )
        )
    }
}
