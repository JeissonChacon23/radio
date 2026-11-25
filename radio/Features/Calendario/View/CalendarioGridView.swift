// radio/Features/Calendario/View/CalendarioGridView.swift

import SwiftUI

struct CalendarioGridView: View {
    let viewModel: CalendarioViewModel

    @Namespace private var selectionNamespace

    private var calendar: Calendar { .current }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Franja superior institucional UFPS
            LinearGradient(
                colors: [Color.ufpsRed, Color.ufpsCrimson],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 5)

            VStack(spacing: 14) {
                header
                Divider()
                weekdayHeader

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                        if let date {
                            DayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedDate),
                                isToday: calendar.isDateInToday(date),
                                hasEvents: viewModel.hasEvents(on: date),
                                namespace: selectionNamespace
                            ) {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                                    viewModel.select(date)
                                }
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .id(viewModel.displayedMonth)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 5)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -50 {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        viewModel.changeMonth(by: 1)
                    }
                } else if value.translation.width > 50 {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        viewModel.changeMonth(by: -1)
                    }
                }
            }
        )
    }

    // MARK: - Encabezado del mes

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.displayedMonth.formatted(.dateTime.month(.wide)).capitalized)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(viewModel.displayedMonth.formatted(.dateTime.year()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                    viewModel.goToToday()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "scope")
                        .font(.caption.bold())
                        .foregroundStyle(Color.ufpsRed)
                    Text("Hoy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        viewModel.changeMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ufpsRed)
                        .frame(width: 32, height: 32)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes anterior")

                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        viewModel.changeMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ufpsRed)
                        .frame(width: 32, height: 32)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes siguiente")
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Cálculo de días

    /// Símbolos de los días de la semana, ordenados según el primer día de la semana del dispositivo.
    private func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Días del mes mostrado, con `nil` para los espacios vacíos al inicio.
    private func daysInMonth() -> [Date?] {
        let month = viewModel.displayedMonth
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: month)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return days
    }
}

// MARK: - Celda de día con efecto deslizante (matchedGeometryEffect)

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ufpsRed, Color.ufpsCrimson],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.ufpsRed.opacity(0.32), radius: 6, y: 3)
                            .matchedGeometryEffect(id: "selected-day-pill", in: namespace)
                    } else if isToday {
                        Circle()
                            .strokeBorder(Color.ufpsRed, lineWidth: 1.5)
                    }

                    Text(date.formatted(.dateTime.day()))
                        .font(.subheadline.weight(isSelected || isToday ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .frame(width: 34, height: 34)

                Circle()
                    .fill(hasEvents ? Color.ufpsRed : Color.clear)
                    .frame(width: 5, height: 5)
                    .scaleEffect(hasEvents && isSelected ? 1.25 : 1.0)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasEvents ? "Tiene eventos" : "Sin eventos")
    }
}
