//
//  MotionManager.swift
//  Dual Camera
//

import CoreMotion
import Foundation
import Observation

@Observable
final class MotionManager {
    private let motionManager = CMMotionManager()
    private(set) var roll: Double = 0

    var isActive: Bool = false {
        didSet {
            if isActive {
                start()
            } else {
                stop()
            }
        }
    }

    private func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let attitude = motion?.attitude else { return }
            self?.roll = attitude.roll
        }
    }

    private func stop() {
        motionManager.stopDeviceMotionUpdates()
        roll = 0
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
