//
//  PodcastResultRow.swift
//  radio
//
//  Created by Foster Chacon on 30/10/26.
//

// radio/Features/Buscar/View/PodcastResultRow.swift

import SwiftUI

struct PodcastResultRow: View {
    let result: PodcastResult

    var body: some View {
        HStack(spacing: 12) {
            DriveArtworkView(id: result.imageId, cornerRadius: 10, pixelSize: 256)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.programName)
                    .font(.headline)
                Text(result.airDate.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        PodcastResultRow(
            result: PodcastResult(
                id: "1",
                programName: "Mañanas UFPS",
                airDate: .now,
                imageId: nil,
                audioId: nil,
                matches: 2
            )
        )
    }
}
