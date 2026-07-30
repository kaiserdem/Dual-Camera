//
//  VideoDebugLog.swift
//  Dual Camera
//

import Foundation

nonisolated enum VideoDebugLog {
    nonisolated static func log(_ message: String, file: String = #fileID, line: Int = #line) {
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        print("[DualVideo] \(fileName):\(line) — \(message)")
    }
}
