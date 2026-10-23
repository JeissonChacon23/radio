// radio/Features/Inicio/View/PlayerView.swift

import SwiftUI

struct PlayerView: View {
    @Environment(RadioPlayerManager.self) private var player

    var body: some View {
        Button {
            player.togglePlayback()
        } label: {
            ZStack {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(player.isBuffering ? 0 : 1)

                if player.isBuffering {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: 64, height: 64)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: Circle())
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
    }
}

#Preview {
    PlayerView()
        .environment(RadioPlayerManager())
}
