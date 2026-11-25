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
    var isStarred: Bool = false
    var onToggleStar: (() -> Void)? = nil

    @State private var showingSafari = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Tarjeta principal del evento con identidad UFPS
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image("ufps_logo")
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text("EVENTO INSTITUCIONAL UFPS")
                            .font(.caption2.bold())
                            .tracking(0.6)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if isStarred {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.ufpsRed)
                                Text("Destacado")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }

                    Text(evento.title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.subheadline)
                            .foregroundStyle(Color.ufpsRed)
                        Text(evento.dateRangeText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if !evento.specialGuest.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.subheadline)
                                .foregroundStyle(Color.ufpsRed)
                            Text("Invitado especial: \(evento.specialGuest)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )

                if !evento.description.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption)
                                .foregroundStyle(Color.ufpsRed)
                            Text("Descripción del evento")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }

                        Text(evento.description)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }

                if evento.link != nil {
                    Button {
                        showingSafari = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "safari.fill")
                                .font(.subheadline.bold())
                            Text("Ver fuente o inscripción oficial")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color.ufpsRed, Color.ufpsCrimson],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .shadow(color: Color.ufpsRed.opacity(0.26), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .navigationTitle("Detalle del evento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onToggleStar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                            onToggleStar()
                        }
                    } label: {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .foregroundStyle(Color.ufpsRed)
                    }
                    .accessibilityLabel(isStarred ? "Quitar de destacados" : "Destacar evento")
                }
            }
        }
        .sheet(isPresented: $showingSafari) {
            if let link = evento.link {
                SafariWebView(url: link)
                    .ignoresSafeArea()
            }
        }
    }
}
