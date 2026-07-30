//
//  Color+Persistence.swift
//  Dual Camera
//

import SwiftUI
import UIKit

extension Color {
    var hexString: String {
        guard let components = rgbaComponents else { return "#FFFFFFFF" }
        return String(
            format: "#%02X%02X%02X%02X",
            Int((components.red * 255).rounded()),
            Int((components.green * 255).rounded()),
            Int((components.blue * 255).rounded()),
            Int((components.alpha * 255).rounded())
        )
    }

    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard hex.count == 6 || hex.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }

        let hasAlpha = hex.count == 8
        let red = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func isApproximatelyEqual(to other: Color, tolerance: CGFloat = 0.02) -> Bool {
        guard let lhs = rgbaComponents, let rhs = other.rgbaComponents else { return false }
        return abs(lhs.red - rhs.red) <= tolerance
            && abs(lhs.green - rhs.green) <= tolerance
            && abs(lhs.blue - rhs.blue) <= tolerance
            && abs(lhs.alpha - rhs.alpha) <= tolerance
    }

    private var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }

        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }

        guard let converted = uiColor.cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ), let parts = converted.components, parts.count >= 3 else {
            return nil
        }

        return (
            parts[0],
            parts[1],
            parts[2],
            parts.count > 3 ? parts[3] : 1
        )
    }
}
