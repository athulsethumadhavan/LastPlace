//
//  AVFoundationCameraCaptureService.swift
//  LastPlace
//
//  AVFoundation-backed camera capture. Session mutations are funneled onto a
//  dedicated serial queue (AVCaptureSession is not `Sendable`) while the public
//  API stays `@MainActor`. Capture delegate callbacks bridge back through a
//  continuation.
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class AVFoundationCameraCaptureService: NSObject, CameraCaptureService {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.lastplace.camera.session")
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<Data, Error>?

    func prepare() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CameraError.notAuthorized }
        case .denied, .restricted:
            throw CameraError.notAuthorized
        @unknown default:
            throw CameraError.notAuthorized
        }

        try configureSessionIfNeeded()
    }

    func start() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [session] in
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [session] in
                if session.isRunning { session.stopRunning() }
                continuation.resume()
            }
        }
    }

    func capturePhoto() async throws -> Data {
        guard captureContinuation == nil else {
            throw CameraError.captureFailed(underlying: "Capture already in progress")
        }

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.flashMode = .auto

        return try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            sessionQueue.async { [photoOutput, weak self] in
                guard let self else { return }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func setTorch(on: Bool) async {
        guard let device, device.hasTorch else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                // Silent — torch is a best-effort convenience.
            }
        }
    }

    func makePreviewView() -> AnyView {
        AnyView(CameraPreviewView(session: session))
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else { return }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        guard let device = discovery.devices.first else {
            throw CameraError.unavailable
        }
        self.device = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                throw CameraError.unavailable
            }

            session.addInput(input)
            session.addOutput(photoOutput)
            session.commitConfiguration()
            isConfigured = true
        } catch let error as CameraError {
            throw error
        } catch {
            throw CameraError.captureFailed(underlying: error.localizedDescription)
        }
    }
}

extension AVFoundationCameraCaptureService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let continuation = self.captureContinuation
            self.captureContinuation = nil

            if let error {
                continuation?.resume(throwing: CameraError.captureFailed(underlying: error.localizedDescription))
                return
            }
            guard let data = photo.fileDataRepresentation() else {
                continuation?.resume(throwing: CameraError.captureFailed(underlying: "Empty photo buffer"))
                return
            }
            continuation?.resume(returning: data)
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
