//
//  GridOverlayView.swift
//  Dual Camera
//

import SwiftUI

struct GridOverlayView: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let thirdWidth = size.width / 3
            let thirdHeight = size.height / 3

            for index in 1...2 {
                let x = thirdWidth * CGFloat(index)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))

                let y = thirdHeight * CGFloat(index)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
