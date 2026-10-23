// radio/Features/Inicio/View/ListenerCountBadge.swift

import SwiftUI

struct ListenerCountBadge: View {
    @Environment(RadioPlayerManager.self) private var player
    @State private var viewModel = ListenerCountViewModel()
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0.6 : 1.0)

            Text(label)
                .font(.subheadline.weight(.medium))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .animation(.default, value: viewModel.count)
        .task { await viewModel.run() }
        .onAppear { updatePulse() }
        .onChange(of: player.isPlaying) { _, _ in
            updatePulse()
            // Da tiempo a que tu presencia se escriba y refresca el conteo
            Task {
                try? await Task.sleep(for: .seconds(2))
                await viewModel.refresh()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        switch viewModel.count {
        case nil: return "En línea"
        case 0: return "Sé el primero en sintonizar"
        case 1: return "1 oyente en línea"
        case let n?: return "\(n) oyentes en línea"
        }
    }

    private func updatePulse() {
        if player.isPlaying {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.default) { pulse = false }
        }
    }
}

#Preview {
    ListenerCountBadge()
        .environment(RadioPlayerManager())
}
