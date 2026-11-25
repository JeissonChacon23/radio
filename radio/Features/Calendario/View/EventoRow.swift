// radio/Features/Calendario/View/EventoRow.swift

import SwiftUI

struct EventoRow: View {
    let evento: Evento
    var isStarred: Bool = false
    var onToggleStar: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Insignia estilo hoja de calendario con franja superior institucional UFPS
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.ufpsRed, Color.ufpsCrimson],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 14)
                .overlay {
                    Text(evento.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(evento.date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
            .frame(width: 50, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(evento.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.ufpsRed)
                    Text(evento.dateRangeText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !evento.specialGuest.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.caption2)
                            .foregroundStyle(Color.ufpsRed)
                        Text("Invitado: \(evento.specialGuest)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                }

                if !evento.description.isEmpty {
                    Text(evento.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            if let onToggleStar {
                Spacer(minLength: 4)

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                        onToggleStar()
                    }
                } label: {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isStarred ? Color.ufpsRed : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 34, height: 34)
                        .background(
                            Color(.tertiarySystemFill),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isStarred ? "Quitar de destacados" : "Destacar evento")
            }
        }
        .padding(.vertical, 2)
    }
}
