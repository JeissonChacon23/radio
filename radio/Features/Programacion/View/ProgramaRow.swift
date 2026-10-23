// radio/Features/Programacion/View/ProgramaRow.swift

import SwiftUI

struct ProgramaRow: View {
    let programa: Programa
    let isOnAir: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(programa.name)
                    .font(.headline)
                if isOnAir {
                    Text("AL AIRE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            Text(programa.timeRangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !programa.collective.isEmpty {
                Text(programa.collective)
                    .font(.footnote)
            }
            if !programa.hosts.isEmpty {
                Text(programa.hosts.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
