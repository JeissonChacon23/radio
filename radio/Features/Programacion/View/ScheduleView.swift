// radio/Features/Programacion/View/ScheduleView.swift

import SwiftUI

struct ScheduleView: View {
    @State private var viewModel = ProgramacionViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                daySelector
                Divider()
                content
            }
            .navigationTitle("Programación")
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Selector horizontal de días

    private var daySelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DiaSemana.all) { dia in
                        DayChip(
                            dia: dia,
                            date: viewModel.date(forISODay: dia.id),
                            isSelected: viewModel.selectedDay == dia.id,
                            isToday: dia.id == ProgramacionViewModel.todayISO()
                        ) {
                            withAnimation(.snappy) {
                                viewModel.selectedDay = dia.id
                            }
                        }
                        .id(dia.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onAppear {
                proxy.scrollTo(viewModel.selectedDay, anchor: .center)
            }
            .onChange(of: viewModel.selectedDay) { _, newValue in
                withAnimation(.snappy) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Contenido vertical

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Cargando programación…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView(
                "Sin conexión",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
            .frame(maxHeight: .infinity)
        } else if viewModel.programasDelDia.isEmpty {
            ContentUnavailableView(
                "Sin programas",
                systemImage: "radio",
                description: Text("No hay programas registrados para este día.")
            )
            .frame(maxHeight: .infinity)
        } else {
            // TimelineView refresca cada minuto para actualizar la etiqueta "AL AIRE"
            TimelineView(.everyMinute) { context in
                List(viewModel.programasDelDia) { programa in
                    ProgramaRow(
                        programa: programa,
                        isOnAir: viewModel.isOnAir(programa, now: context.date)
                    )
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Chip de día

private struct DayChip: View {
    let dia: DiaSemana
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dia.short.uppercased())
                    .font(.caption.weight(.semibold))

                Text(date.formatted(.dateTime.day()))
                    .font(.title3.bold())

                Circle()
                    .fill(isToday ? (isSelected ? Color.white : Color.accentColor) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 56, height: 74)
            .background(
                isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dia.full) \(date.formatted(.dateTime.day()))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ScheduleView()
}
