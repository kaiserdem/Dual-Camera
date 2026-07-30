//
//  AppSettings.swift
//  Dual Camera
//

import Foundation
import Observation
import SwiftUI

@Observable
final class AppSettings {
    private enum Keys {
        static let layout = "settings.layout"
        static let pipShape = "settings.pipShape"
        static let pipRounded = "settings.pipRounded"
        static let pipScale = "settings.pipScale"
        static let borderEnabled = "settings.borderEnabled"
        static let borderWidth = "settings.borderWidth"
        static let borderStyle = "settings.borderStyle"
        static let borderColor = "settings.borderColor"
        static let borderLineStyle = "settings.borderLineStyle"
        static let selectedRatio = "settings.selectedRatio"
        static let verticalSplitRatio = "settings.verticalSplitRatio"
        static let horizontalSplitRatio = "settings.horizontalSplitRatio"
    }

    var selectedLayout: CameraLayout = .pip {
        didSet { persist(selectedLayout.rawValue, key: Keys.layout) }
    }

    var pipShape: PiPShape = .square {
        didSet { persist(pipShape.rawValue, key: Keys.pipShape) }
    }

    /// Rounded corners for square / rectangle PiP. Ignored for circle.
    var isPiPRounded: Bool = true {
        didSet { persist(isPiPRounded, key: Keys.pipRounded) }
    }

    /// PiP width as a fraction of viewfinder width. Typical range 0.18...0.45.
    var pipScale: CGFloat = 0.28 {
        didSet { persist(Double(pipScale), key: Keys.pipScale) }
    }

    var isBorderEnabled: Bool = true {
        didSet { persist(isBorderEnabled, key: Keys.borderEnabled) }
    }

    var borderWidth: CGFloat = 2 {
        didSet { persist(Double(borderWidth), key: Keys.borderWidth) }
    }

    var borderStyle: BorderStyle = .white {
        didSet { persist(borderStyle.rawValue, key: Keys.borderStyle) }
    }

    /// Stored as hex to avoid Color conversion crashes during Observation init.
    var borderColorHex: String = BorderStyle.white.hexValue {
        didSet { persist(borderColorHex, key: Keys.borderColor) }
    }

    var borderLineStyle: BorderLineStyle = .dashed {
        didSet { persist(borderLineStyle.rawValue, key: Keys.borderLineStyle) }
    }

    var selectedRatio: AspectRatio = .full {
        didSet { persist(selectedRatio.rawValue, key: Keys.selectedRatio) }
    }

    /// Primary camera share for side-by-side (Vertical) layout. 0.2...0.8
    var verticalSplitRatio: CGFloat = 0.5 {
        didSet { persist(Double(verticalSplitRatio), key: Keys.verticalSplitRatio) }
    }

    /// Primary camera share for stacked (Horizontal) layout. 0.2...0.8
    var horizontalSplitRatio: CGFloat = 0.5 {
        didSet { persist(Double(horizontalSplitRatio), key: Keys.horizontalSplitRatio) }
    }

    var borderColor: Color {
        get { Color(hexString: borderColorHex) ?? BorderStyle.white.color }
        set { borderColorHex = newValue.hexString }
    }

    private var isRestoring = false

    init() {
        isRestoring = true
        defer { isRestoring = false }

        let defaults = UserDefaults.standard
        selectedLayout = CameraLayout(rawValue: defaults.string(forKey: Keys.layout) ?? "") ?? .pip
        (pipShape, isPiPRounded) = Self.migratedPiPShape(
            rawShape: defaults.string(forKey: Keys.pipShape),
            rawRounded: defaults.object(forKey: Keys.pipRounded) as? Bool
        )
        isBorderEnabled = defaults.object(forKey: Keys.borderEnabled) as? Bool ?? true
        let storedWidth = defaults.object(forKey: Keys.borderWidth) as? Double
        borderWidth = CGFloat(storedWidth ?? 2)
        borderStyle = BorderStyle(rawValue: defaults.string(forKey: Keys.borderStyle) ?? "") ?? .white
        borderLineStyle = BorderLineStyle(rawValue: defaults.string(forKey: Keys.borderLineStyle) ?? "") ?? .dashed
        selectedRatio = AspectRatio(rawValue: defaults.string(forKey: Keys.selectedRatio) ?? "") ?? .full

        if let hex = defaults.string(forKey: Keys.borderColor), Color(hexString: hex) != nil {
            borderColorHex = hex
        } else {
            borderColorHex = borderStyle.hexValue
        }

        verticalSplitRatio = Self.clampedSplitRatio(
            defaults.object(forKey: Keys.verticalSplitRatio) as? Double ?? 0.5
        )
        horizontalSplitRatio = Self.clampedSplitRatio(
            defaults.object(forKey: Keys.horizontalSplitRatio) as? Double ?? 0.5
        )
        pipScale = Self.clampedPipScale(
            defaults.object(forKey: Keys.pipScale) as? Double ?? 0.28
        )
    }

    func applyBorderPreset(_ style: BorderStyle) {
        borderStyle = style
        borderColorHex = style.hexValue
    }

    static func clampedSplitRatio(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0.2), 0.8))
    }

    static func clampedPipScale(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0.18), 0.45))
    }

    /// Maps legacy `roundedSquare` to square + rounded switch.
    private static func migratedPiPShape(rawShape: String?, rawRounded: Bool?) -> (PiPShape, Bool) {
        switch rawShape {
        case "roundedSquare":
            return (.square, true)
        case "rectangle":
            return (.rectangle, rawRounded ?? true)
        case "circle":
            return (.circle, rawRounded ?? true)
        case "square":
            return (.square, rawRounded ?? true)
        default:
            return (.square, rawRounded ?? true)
        }
    }

    private func persist(_ value: Any, key: String) {
        guard !isRestoring else { return }
        UserDefaults.standard.set(value, forKey: key)
    }
}
