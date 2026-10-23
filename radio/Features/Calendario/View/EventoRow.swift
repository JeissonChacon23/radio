// radio/Features/Calendario/View/EventoRow.swift

//
//  EventoRow.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import SwiftUI

struct EventoRow: View {
    let evento: Evento

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(evento.date.formatted(.dateTime.day()))
                    .font(.title2.bold())
                Text(evento.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(evento.title)
                    .font(.headline)
                Text(evento.dateRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
