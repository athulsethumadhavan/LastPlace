//
//  CameraCaptureService.swift
//  LastPlace
//
//  Cross-cutting port for still-image capture. Vends a live preview and produces
//  JPEG `Data` on shutter. Concrete `AVFoundation` and mock implementations live
//  alongside; view models depend on this protocol only.
//

import Foundation
import SwiftUI

@MainActor
protocol CameraCaptureService: AnyObject {
    /// Prompts / returns the current camera authorization. Throws
    /// `CameraError.notAuthorized` when the user has denied access, or
    /// `CameraError.unavailable` when the hardware isn't present.
    func prepare() async throws

    /// Starts the underlying capture session. Safe to call more than once.
    func start() async

    /// Stops the capture session and releases the preview layer output.
    func stop() async

    /// Captures a single still frame and returns JPEG bytes.
    func capturePhoto() async throws -> Data

    /// Toggles the rear-camera torch. No-op if the device has no torch.
    func setTorch(on: Bool) async

    /// SwiftUI view that renders the live preview backed by this service.
    func makePreviewView() -> AnyView
}
