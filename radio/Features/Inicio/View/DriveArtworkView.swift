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
                        Color.white
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
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
