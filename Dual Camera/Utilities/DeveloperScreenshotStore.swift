//
//  DeveloperScreenshotStore.swift
//  Dual Camera
//

#if DEBUG

import UIKit

/// Persists mock camera stills for App Store screenshot staging (developer mode).
enum DeveloperScreenshotStore {
    private static let folderName = "DeveloperScreenshotMocks"
    private static let backFileName = "mock-back.jpg"
    private static let frontFileName = "mock-front.jpg"

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func loadBackImage() -> UIImage? {
        loadImage(named: backFileName)
    }

    static func loadFrontImage() -> UIImage? {
        loadImage(named: frontFileName)
    }

    static func saveBackImage(_ image: UIImage) {
        saveImage(image, named: backFileName)
    }

    static func saveFrontImage(_ image: UIImage) {
        saveImage(image, named: frontFileName)
    }

    static func clearBackImage() {
        removeImage(named: backFileName)
    }

    static func clearFrontImage() {
        removeImage(named: frontFileName)
    }

    private static func loadImage(named name: String) -> UIImage? {
        let url = directoryURL.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func saveImage(_ image: UIImage, named name: String) {
        let url = directoryURL.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.92) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func removeImage(named name: String) {
        let url = directoryURL.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }
}

#endif
