//
//  BiometricAuthenticator.swift
//  LastPlace
//
//  Protocol-wrapped LocalAuthentication, mirroring `CameraCaptureService` /
//  `ObjectDetectionService` — a swappable Core service so `AppCoordinator`
//  and the Security settings screen never import `LocalAuthentication`
//  directly and previews/tests can inject a deterministic mock.
//

import Foundation

/// What kind of biometry (if any) the device supports. Read passively via
/// `availableBiometry()` — doesn't prompt or require Settings access, same
/// spirit as `CameraAuthorization.currentStatus()`.
enum BiometryKind: Sendable, Equatable {
    case faceID
    case touchID
    case opticID
    case none

    var displayName: String {
        switch self {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none:    return "Biometric authentication"
        }
    }

    var symbolName: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none:    return "lock"
        }
    }

    var isAvailable: Bool { self != .none }
}

protocol BiometricAuthenticator: Sendable {
    /// What the device supports, without prompting. Used to decide whether
    /// the Security toggle is offered at all.
    func availableBiometry() -> BiometryKind

    /// Prompts Face ID / Touch ID (with the system's own passcode fallback
    /// button). Returns `true` only on successful authentication — a
    /// cancelled or failed attempt returns `false` rather than throwing, so
    /// callers can just show a retry affordance.
    func authenticate(reason: String) async -> Bool
}
