// radio/Features/Calendario/View/CalendarioView.swift

import SwiftUI

struct CalendarioView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = CalendarioViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Cargando eventos…")
                } else if let message = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Sin conexión",
                        systemImage: "wifi.exclamationmark",
                        description: Text(message)
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Calendario")
            .navigationDestination(for: Evento.self) { evento in
                EventoDetalleView(evento: evento)
            }
        }
        .onAppear {
            if let profile = session.profile {
                viewModel.start(profile: profile)
            }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Contenido

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CalendarioGridView(viewModel: viewModel)

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted).capitalized)
                        .font(.headline)

                    let eventos = viewModel.selectedEventos

                    if eventos.isEmpty {
                        ContentUnavailableView(
                            "Sin eventos",
                            systemImage: "calendar",
                            description: Text("No hay eventos para este día.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(eventos) { evento in
                            NavigationLink(value: evento) {
                                HStack {
                                    EventoRow(evento: evento)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .animation(.default, value: viewModel.selectedDate)
            }
            .padding()
        }
    }
}
