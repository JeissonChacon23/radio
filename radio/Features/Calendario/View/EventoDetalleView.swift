// radio/Features/Calendario/View/EventoDetalleView.swift

//
//  EventoDetalleView.swift
//  radio
//
//  Created by Foster Chacon on 22/10/26.
//

import SwiftUI

struct EventoDetalleView: View {
    let evento: Evento

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(evento.title)
                    .font(.title2.bold())

                Label(evento.dateRangeText, systemImage: "calendar")
                    .foregroundStyle(.secondary)

                if !evento.description.isEmpty {
                    Text(evento.description)
                }

                if let link = evento.link {
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
