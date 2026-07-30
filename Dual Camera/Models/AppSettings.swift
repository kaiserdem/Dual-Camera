//
//  AppSettings.swift
//  Dual Camera
//

import Foundation
import Observation

@Observable
final class AppSettings {
    private enum Keys {
        static let layout = "settings.layout"
        static let pipShape = "settings.pipShape"
        static let borderEnabled = "settings.borderEnabled"
        static let borderWidth = "settings.borderWidth"
        static let borderStyle = "settings.borderStyle"
        static let selectedRatio = "settings.selectedRatio"
    }

    var selectedLayout: CameraLayout {
        didSet { UserDefaults.standard.set(selectedLayout.rawValue, forKey: Keys.layout) }
    }

    var pipShape: PiPShape {
        didSet { UserDefaults.standard.set(pipShape.rawValue, forKey: Keys.pipShape) }
    }

    var isBorderEnabled: Bool {
        didSet { UserDefaults.standard.set(isBorderEnabled, forKey: Keys.borderEnabled) }
    }

    var borderWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(borderWidth), forKey: Keys.borderWidth) }
    }

    var borderStyle: BorderStyle {
        didSet { UserDefaults.standard.set(borderStyle.rawValue, forKey: Keys.borderStyle) }
    }

    var selectedRatio: AspectRatio {
        didSet { UserDefaults.standard.set(selectedRatio.rawValue, forKey: Keys.selectedRatio) }
    }

    init() {
        let defaults = UserDefaults.standard
        selectedLayout = CameraLayout(rawValue: defaults.string(forKey: Keys.layout) ?? "") ?? .pip
        pipShape = PiPShape(rawValue: defaults.string(forKey: Keys.pipShape) ?? "") ?? .roundedSquare
        isBorderEnabled = defaults.object(forKey: Keys.borderEnabled) as? Bool ?? true
        let storedWidth = defaults.object(forKey: Keys.borderWidth) as? Double
        borderWidth = CGFloat(storedWidth ?? 2)
        borderStyle = BorderStyle(rawValue: defaults.string(forKey: Keys.borderStyle) ?? "") ?? .white
        selectedRatio = AspectRatio(rawValue: defaults.string(forKey: Keys.selectedRatio) ?? "") ?? .full
    }
}
