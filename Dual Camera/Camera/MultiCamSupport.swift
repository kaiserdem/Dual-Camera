//
//  MultiCamSupport.swift
//  Dual Camera
//

import AVFoundation

enum MultiCamSupport {
    static var isSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    static var unsupportedMessage: String {
        "Multi-camera capture requires an iPhone or iPad with an A12 Bionic chip or later."
    }
}
