// radio/Features/Calendario/View/CalendarioView.swift

import SwiftUI

struct CalendarioView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = CalendarioViewModel()
    @State private var showingStarredSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundDecor

                Group {
                    if viewModel.isLoading {
                        ProgressView("Cargando agenda universitaria…")
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
            }
            .navigationTitle("Calendario")
            .navigationDestination(for: Evento.self) { evento in
                EventoDetalleView(
                    evento: evento,
                    isStarred: viewModel.isStarred(evento),
                    onToggleStar: { viewModel.toggleStar(evento) }
                )
            }
            .sheet(isPresented: $showingStarredSheet) {
                EventosDestacadosSheet(viewModel: viewModel)
            }
        }
        .onAppear {
            if let profile = session.profile {
                viewModel.start(profile: profile)
            }
        }
        .onChange(of: session.profile) { _, newProfile in
            if let newProfile {
                viewModel.start(profile: newProfile)
            }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Resplandor institucional sutil

    private var backgroundDecor: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.ufpsRed.opacity(0.14),
                                Color.ufpsCrimson.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: geo.size.width * 0.75
                        )
                    )
                    .frame(width: geo.size.width * 1.3, height: geo.size.width * 1.3)
                    .position(x: geo.size.width * 0.5, y: -geo.size.width * 0.2)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Contenido principal

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                institutionalBanner

                CalendarioGridView(viewModel: viewModel)

                selectedDaySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Encabezado corporativo UFPS con acceso a Eventos Destacados

    private var institutionalBanner: some View {
        let starredCount = viewModel.starredEventos.count

        return Button {
            showingStarredSheet = true
        } label: {
            HStack(spacing: 12) {
                Image("ufps_logo")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agenda Universitaria UFPS")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(
                        session.profile.map { "Eventos para \($0.profileType.title)" }
                            ?? "Eventos y actividades institucionales"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Image(systemName: starredCount > 0 ? "star.fill" : "star")
                        .font(.caption2.bold())
                        .foregroundStyle(starredCount > 0 ? Color.white : Color.ufpsRed)
                    Text("\(starredCount)")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(starredCount > 0 ? Color.white : Color.primary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background {
                    if starredCount > 0 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ufpsRed, Color.ufpsCrimson],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    }
                }
            }
            .padding(14)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ver eventos destacados")
    }

    // MARK: - Eventos del día seleccionado

    private var selectedDaySection: some View {
        let eventos = viewModel.selectedEventos

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ufpsRed)

                Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted).capitalized)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Spacer()

                if !eventos.isEmpty {
                    Text(eventos.count == 1 ? "1 evento" : "\(eventos.count) eventos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .padding(.horizontal, 4)

            if eventos.isEmpty {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 52, height: 52)
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title3)
                            .foregroundStyle(Color.ufpsRed)
                    }

                    Text("Sin eventos programados")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("No hay actividades registradas para este día. Los días con punto rojo en el calendario tienen eventos activos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 16)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 10) {
                    ForEach(eventos) { evento in
                        NavigationLink(value: evento) {
                            HStack(spacing: 8) {
                                EventoRow(
                                    evento: evento,
                                    isStarred: viewModel.isStarred(evento),
                                    onToggleStar: { viewModel.toggleStar(evento) }
                                )
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedDate)
    }
}

// MARK: - Hoja de Eventos Destacados por el usuario

private struct EventosDestacadosSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: CalendarioViewModel

    var body: some View {
        NavigationStack {
            Group {
                let destacados = viewModel.starredEventos

                if destacados.isEmpty {
                    ContentUnavailableView {
                        Label("Sin eventos destacados", systemImage: "star.slash")
                            .foregroundStyle(.primary, Color.ufpsRed)
                    } description: {
                        Text("Toca la estrella en cualquier evento del calendario para guardarlo aquí y consultarlo rápidamente cuando quieras.")
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(destacados) { evento in
                                VStack(alignment: .leading, spacing: 10) {
                                    NavigationLink {
                                        EventoDetalleView(
                                            evento: evento,
                                            isStarred: viewModel.isStarred(evento),
                                            onToggleStar: { viewModel.toggleStar(evento) }
                                        )
                                    } label: {
                                        EventoRow(
                                            evento: evento,
                                            isStarred: true,
                                            onToggleStar: { viewModel.toggleStar(evento) }
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    Divider()

                                    Button {
                                        viewModel.jumpTo(evento)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "calendar.badge.clock")
                                                .font(.caption.bold())
                                                .foregroundStyle(Color.ufpsRed)
                                            Text("Ver este día en el calendario")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(Color.ufpsRed)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)
                                .background(
                                    Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Eventos destacados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

#Preview {
    CalendarioView()
        .environment(SessionStore(previewState: .ready(UserProfile(profileType: .estudiante, careerId: "ingenieria-sistemas"))))
}
