//
//  DualCameraLegal.swift
//  Dual Camera
//

import Foundation

/// Public legal URLs (GitHub Pages). Update if the repo name or GitHub user changes.
enum DualCameraLegal {
    static let appName = "DuoPrompter"
    static let tagline = "Dual camera & teleprompter"

    private static let pagesBase = "https://hoksv.github.io/dual-camera-legal"

    static let privacyURL = URL(string: "\(pagesBase)/privacy.html")!
    static let termsURL = URL(string: "\(pagesBase)/terms.html")!
    static let supportEmail = "nikolovalena1616@gmail.com"
    static let contactURL = URL(string: "mailto:\(supportEmail)")!

    /// Set after App Store Connect creates the app record (e.g. `"1234567890"`).
    static let appStoreID: String? = "6809437163"

    static var rateURL: URL? {
        guard let appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
