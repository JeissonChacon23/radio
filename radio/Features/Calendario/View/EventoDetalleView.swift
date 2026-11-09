// radio/Features/Calendario/View/EventoDetalleView.swift

import SwiftUI
import SafariServices

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct EventoDetalleView: View {
    let evento: Evento
    @State private var showingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(evento.title)
                    .font(.title2.bold())

                Label(evento.dateRangeText, systemImage: "calendar.badge.clock")
                    .foregroundStyle(.secondary)

                if !evento.specialGuest.isEmpty {
                    Label("Invitado especial: \(evento.specialGuest)", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }

                if !evento.description.isEmpty {
                    Divider()
                    Text(evento.description)
                        .font(.body)
                }

                if evento.link != nil {
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
            if let link = evento.link {
                SafariWebView(url: link)
                    .ignoresSafeArea()
            }
        }
    }
}
