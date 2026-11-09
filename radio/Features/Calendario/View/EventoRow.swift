// radio/Features/Calendario/View/EventoRow.swift

import SwiftUI

struct EventoRow: View {
    let evento: Evento

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(evento.date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                    .foregroundStyle(Color.ufpsRed)
                Text(evento.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.ufpsRed.opacity(0.85))
            }
            .frame(width: 50, height: 52)
            .background(Color.ufpsRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(evento.title)
                    .font(.headline)
                Text(evento.dateRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !evento.specialGuest.isEmpty {
                    Label("Invitado: \(evento.specialGuest)", systemImage: "star.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ufpsRed)
                }
                if !evento.description.isEmpty {
                    Text(evento.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
