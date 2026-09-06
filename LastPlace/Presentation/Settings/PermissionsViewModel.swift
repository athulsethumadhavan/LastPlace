//
//  PermissionsViewModel.swift
//  LastPlace
//
//  A passive status read, not a mutation — the actual permission prompt only
//  ever fires from the scan flow itself (`CameraCaptureService.prepare()`).
//  This just reflects whatever the system's current answer is and, once
//  denied, hands the user off to Settings to change it.
//

import Foundation
import Observation

@Observable
@MainActor
final class PermissionsViewModel {
    private(set) var cameraStatus: CameraAuthorizationStatus = .notDetermined

    func refresh() {
        cameraStatus = CameraAuthorization.currentStatus()
    }
}
