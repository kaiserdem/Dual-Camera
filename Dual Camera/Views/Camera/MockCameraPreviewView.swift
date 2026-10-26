//
//  MockCameraPreviewView.swift
//  Dual Camera
//

import SwiftUI

/// Still image stand-in for a live camera preview (developer screenshot mode).
struct MockCameraPreviewView: View {
    let image: UIImage
    var mirrored: Bool = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .accessibilityLabel("Mock camera preview")
    }
}
