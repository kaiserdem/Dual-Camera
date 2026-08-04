//
//  VideoDebugLog.swift
//  Dual Camera
//

import Foundation

/// Temporary latency diagnostics for record / pause / stop taps.
nonisolated enum VideoDebugLog {
    private static let lock = NSLock()
    private static var markDate: Date?
    private static var markLabel: String = ""

    /// Call at the UI tap site. Later logs print Δms from this mark.
    nonisolated static func markTap(_ label: String) {
        lock.lock()
        markDate = Date()
        markLabel = label
        lock.unlock()
        print("[DualVideo][TAP] ▶ \(label) t=0.0ms")
    }

    nonisolated static func log(_ message: String, file: String = #fileID, line: Int = #line) {
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        let delta: String
        lock.lock()
        if let start = markDate {
            let ms = Date().timeIntervalSince(start) * 1000
            delta = String(format: " Δ=%.1fms (from %@)", ms, markLabel)
        } else {
            delta = ""
        }
        lock.unlock()
        print("[DualVideo] \(fileName):\(line) — \(message)\(delta)")
    }
}
