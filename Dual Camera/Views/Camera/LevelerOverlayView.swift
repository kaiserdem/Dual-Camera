//
//  LevelerOverlayView.swift
//  Dual Camera
//

import SwiftUI

struct LevelerOverlayView: View {
    let roll: Double

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.55, 220)
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: width, height: 3)
                    .rotationEffect(.radians(roll))

                Circle()
                    .stroke(.yellow.opacity(0.9), lineWidth: 2)
                    .frame(width: 10, height: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}
