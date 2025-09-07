//
//  Configuration.swift
//  DuctTape
//

import Foundation

enum Configuration {
    // UI
    static let maxMenuWidth: CGFloat = 350

    // Scripts
    static let outputLineCharacterLimit = 200
    static let outputBufferLimitDefault = 500
    static let outputBufferLimitMax = 10000
    static let outputThrottleInterval: TimeInterval = 1.0
    static let scriptRestartDelay: TimeInterval = 0.5
    static let scriptTerminationDelay: TimeInterval = 0.1

    // Timing
    static let outputActivityDuration: TimeInterval = 5.0
    static let dockIconDelay: TimeInterval = 0.5
    static let appTerminationDelay: TimeInterval = 0.5
}
