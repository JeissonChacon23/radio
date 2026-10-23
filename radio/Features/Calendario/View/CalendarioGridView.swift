//
//  CalendarioGridView.swift
//  radio
//
//  Created by Foster Chacon on 23/10/26.
//

import SwiftUI

struct CalendarioGridView: View {
    let viewModel: CalendarioViewModel

    private var calendar: Calendar { .current }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvents: viewModel.hasEvents(on: date)
                        ) {
                            viewModel.select(date)
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -50 {
                    withAnimation { viewModel.changeMonth(by: 1) }
                } else if value.translation.width > 50 {
                    withAnimation { viewModel.changeMonth(by: -1) }
                }
            }
        )
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack {
            Text(viewModel.displayedMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                .font(.title3.bold())

            Spacer()

            Button("Hoy") {
                withAnimation { viewModel.goToToday() }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.trailing, 8)

            Button {
                withAnimation { viewModel.changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Mes anterior")

            Button {
                withAnimation { viewModel.changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Mes siguiente")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.caption.weight(.semibold))
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

// MARK: - Celda de día

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.body.weight(isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(hasEvents ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
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
