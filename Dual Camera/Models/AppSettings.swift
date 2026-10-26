//
//  AppSettings.swift
//  Dual Camera
//

import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class AppSettings {
    private enum Keys {
        static let layout = "settings.layout"
        static let teleprompterText = "settings.teleprompterText"
        static let teleprompterSpeed = "settings.teleprompterSpeed"
        static let teleprompterFontSize = "settings.teleprompterFontSize"
        static let teleprompterAutoStartWithRecording = "settings.teleprompterAutoStartWithRecording"
        static let teleprompterStartDelaySeconds = "settings.teleprompterStartDelaySeconds"
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
        static let videoCodec = "settings.videoCodec"
        static let videoContainer = "settings.videoContainer"
        static let videoResolution = "settings.videoResolution"
        static let floatingCameraChrome = "settings.floatingCameraChrome"
        static let fullBleedCameraBackground = "settings.fullBleedCameraBackground"
        static let flashMode = "settings.flashMode"
        static let developerModeEnabled = "settings.developerModeEnabled"
        static let developerScreenshotMode = "settings.developerScreenshotMode"
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

    var videoCodec: VideoCodecOption = .hevc {
        didSet { persist(videoCodec.rawValue, key: Keys.videoCodec) }
    }

    var videoContainer: VideoContainerOption = .mov {
        didSet { persist(videoContainer.rawValue, key: Keys.videoContainer) }
    }

    var videoResolution: VideoResolutionOption = .p1080 {
        didSet { persist(videoResolution.rawValue, key: Keys.videoResolution) }
    }

    /// Floating frosted top/bottom bars on the camera screen (new design).
    var isFloatingCameraChromeEnabled: Bool = true {
        didSet { persist(isFloatingCameraChromeEnabled, key: Keys.floatingCameraChrome) }
    }

    /// Edge-to-edge live preview instead of a black letterbox stage.
    var isFullBleedCameraBackgroundEnabled: Bool = true {
        didSet { persist(isFullBleedCameraBackgroundEnabled, key: Keys.fullBleedCameraBackground) }
    }

    /// Last flash (photo) / torch (video) mode. Restored across launches.
    var flashMode: FlashModeOption = .off {
        didSet { persist(flashMode.rawValue, key: Keys.flashMode) }
    }

    // MARK: - Teleprompter

    /// Script text displayed in the teleprompter overlay.
    var teleprompterText: String = "" {
        didSet { persist(teleprompterText, key: Keys.teleprompterText) }
    }

    /// Scroll speed multiplier for the teleprompter (0.2 … 3.0).
    var teleprompterSpeed: Double = 1.0 {
        didSet { persist(teleprompterSpeed, key: Keys.teleprompterSpeed) }
    }

    /// Overlay font size in points (12 … 48). Default matches previous hardcoded size.
    var teleprompterFontSize: Double = 28 {
        didSet { persist(teleprompterFontSize, key: Keys.teleprompterFontSize) }
    }

    /// When true, starting a video recording activates the teleprompter (if script text exists).
    var teleprompterAutoStartWithRecording: Bool = false {
        didSet { persist(teleprompterAutoStartWithRecording, key: Keys.teleprompterAutoStartWithRecording) }
    }

    /// Seconds to wait before scrolling begins after activation (0 / 3 / 5 / 10).
    var teleprompterStartDelaySeconds: Int = 0 {
        didSet {
            let clamped = Self.clampedTeleprompterStartDelay(teleprompterStartDelaySeconds)
            if clamped != teleprompterStartDelaySeconds {
                teleprompterStartDelaySeconds = clamped
                return
            }
            persist(teleprompterStartDelaySeconds, key: Keys.teleprompterStartDelaySeconds)
        }
    }

    /// Allowed countdown presets for teleprompter start delay.
    static let teleprompterDelayOptions: [Int] = [0, 3, 5, 10]

    /// Runtime-only flag — not persisted.
    var isTeleprompterActive: Bool = false

    /// Runtime-only: whether the overlay should scroll (after optional countdown).
    var isTeleprompterScrolling: Bool = false

    // MARK: - Developer (screenshot staging; hide before App Store release)

    /// Unlocks developer-only settings in the app.
    var isDeveloperModeEnabled: Bool = false {
        didSet { persist(isDeveloperModeEnabled, key: Keys.developerModeEnabled) }
    }

    /// Replaces live camera previews with gallery stills (back + front slots).
    var isDeveloperScreenshotModeEnabled: Bool = false {
        didSet { persist(isDeveloperScreenshotModeEnabled, key: Keys.developerScreenshotMode) }
    }

    private(set) var developerMockBackImage: UIImage?
    private(set) var developerMockFrontImage: UIImage?

    var hasDeveloperScreenshotMocks: Bool {
        developerMockBackImage != nil && developerMockFrontImage != nil
    }

    func reloadDeveloperMockImages() {
        developerMockBackImage = DeveloperScreenshotStore.loadBackImage()
        developerMockFrontImage = DeveloperScreenshotStore.loadFrontImage()
    }

    func setDeveloperMockBackImage(_ image: UIImage) {
        DeveloperScreenshotStore.saveBackImage(image)
        developerMockBackImage = image
    }

    func setDeveloperMockFrontImage(_ image: UIImage) {
        DeveloperScreenshotStore.saveFrontImage(image)
        developerMockFrontImage = image
    }

    func clearDeveloperMockBackImage() {
        DeveloperScreenshotStore.clearBackImage()
        developerMockBackImage = nil
    }

    func clearDeveloperMockFrontImage() {
        DeveloperScreenshotStore.clearFrontImage()
        developerMockFrontImage = nil
    }

    var videoExportConfiguration: VideoExportConfiguration {
        VideoExportConfiguration(
            codec: videoCodec,
            container: videoContainer,
            resolution: videoResolution
        )
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
        videoCodec = VideoCodecOption(rawValue: defaults.string(forKey: Keys.videoCodec) ?? "") ?? .hevc
        videoContainer = VideoContainerOption(rawValue: defaults.string(forKey: Keys.videoContainer) ?? "") ?? .mov
        videoResolution = VideoResolutionOption(rawValue: defaults.string(forKey: Keys.videoResolution) ?? "") ?? .p1080
        isFloatingCameraChromeEnabled = defaults.object(forKey: Keys.floatingCameraChrome) as? Bool ?? true
        isFullBleedCameraBackgroundEnabled = defaults.object(forKey: Keys.fullBleedCameraBackground) as? Bool ?? true
        flashMode = FlashModeOption(rawValue: defaults.string(forKey: Keys.flashMode) ?? "") ?? .off
        teleprompterText = defaults.string(forKey: Keys.teleprompterText) ?? ""
        teleprompterSpeed = defaults.object(forKey: Keys.teleprompterSpeed) as? Double ?? 1.0
        teleprompterFontSize = Self.clampedTeleprompterFontSize(
            defaults.object(forKey: Keys.teleprompterFontSize) as? Double ?? 28
        )
        teleprompterAutoStartWithRecording =
            defaults.object(forKey: Keys.teleprompterAutoStartWithRecording) as? Bool ?? false
        teleprompterStartDelaySeconds = Self.clampedTeleprompterStartDelay(
            defaults.object(forKey: Keys.teleprompterStartDelaySeconds) as? Int ?? 0
        )
        isDeveloperModeEnabled = defaults.object(forKey: Keys.developerModeEnabled) as? Bool ?? false
        isDeveloperScreenshotModeEnabled =
            defaults.object(forKey: Keys.developerScreenshotMode) as? Bool ?? false
        reloadDeveloperMockImages()
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

    static func clampedTeleprompterFontSize(_ value: Double) -> Double {
        min(max(value, 12), 48)
    }

    static func clampedTeleprompterStartDelay(_ value: Int) -> Int {
        if teleprompterDelayOptions.contains(value) { return value }
        return teleprompterDelayOptions.min(by: { abs($0 - value) < abs($1 - value) }) ?? 0
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
