// radio/Features/Inicio/View/DriveArtworkView.swift

import SwiftUI

struct DriveArtworkView: View {
    let id: String?
    var cornerRadius: CGFloat = 24
    var pixelSize: Int = 1024

    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [.red.opacity(0.85), .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .resizable()
                            .scaledToFit()
                            .padding(pixelSize > 512 ? 64 : 14)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: id) {
                image = nil
                guard let id, !RuntimeEnvironment.isPreview else { return }
                if let data = await DriveImageLoader.loadData(id: id, size: pixelSize) {
                    image = UIImage(data: data)
                } else if !Task.isCancelled {
                    print("DriveArtworkView: could not load the image for", id)
                }
            }
    }
}

#Preview {
    DriveArtworkView(id: nil)
        .frame(maxWidth: 320)
        .padding()
}
