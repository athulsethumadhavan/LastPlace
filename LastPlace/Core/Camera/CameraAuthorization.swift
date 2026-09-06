//
//  CameraAuthorization.swift
//  LastPlace
//
//  Read-only camera permission status for the Settings > Permissions screen.
//  Kept separate from `CameraCaptureService` because that protocol's
//  `prepare()` has a side effect (it prompts the system dialog on first ask);
//  this is a passive query so a settings screen can display status without
//  accidentally triggering the prompt.
//

import AVFoundation

enum CameraAuthorizationStatus: Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined

    var displayName: String {
        switch self {
        case .authorized:    return "Allowed"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not requested yet"
        }
    }

    /// `true` when the camera can be used without further action from the user.
    var isGranted: Bool {
        self == .authorized
    }
}

enum CameraAuthorization {
    /// Reads the current status without prompting. Safe to call as often as
    /// needed (e.g. every time the Permissions screen reappears).
    static func currentStatus() -> CameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:          return .authorized
        case .denied:              return .denied
        case .restricted:          return .restricted
        case .notDetermined:       return .notDetermined
        @unknown default:          return .notDetermined
        }
    }
}
