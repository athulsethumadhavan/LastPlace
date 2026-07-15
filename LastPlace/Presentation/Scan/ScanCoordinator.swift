//
//  ScanCoordinator.swift
//  LastPlace
//
//  Owns a single `ScanSession` and drives the capture → review → save sub-flow
//  as internal state (not additional NavigationStack pushes). Coordinates use
//  cases against the container and vends the child view models the sub-screens
//  need. Lifecycle: `startSession()` on appear, `cancelSession()` on swipe-back,
//  `completeSession()` on Done.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ScanCoordinator {
    enum Screen: Equatable {
        case capture
        case review
        case saveDetection(captureID: UUID, detection: DetectedObject)
    }

    struct ScanCapture: Identifiable, Hashable {
        let id: UUID
        let imagePath: String
        var imageData: Data
        var detections: [DetectedObject]
        var isDetecting: Bool
    }

    // MARK: Observable state

    var screen: Screen = .capture
    var isStartingSession: Bool = false
    var isCapturing: Bool = false
    var isCompleting: Bool = false
    var torchOn: Bool = false
    var errorAlert: UserFacingError?
    private(set) var captures: [ScanCapture] = []
    private(set) var session: ScanSession?

    // MARK: Dependencies

    let roomID: UUID
    let container: AppDependencyContainer
    let camera: CameraCaptureService

    private let startScan: StartScanSessionUseCase
    private let appendScan: AppendScanImageUseCase
    private let completeScan: CompleteScanSessionUseCase
    private let cancelScan: CancelScanSessionUseCase
    private let saveItem: SaveItemUseCase
    private let detection: ObjectDetectionService
    private let logger: AppLogger

    /// Detections below this threshold are hidden in the review UI to keep the
    /// list focused on identifiable objects.
    private let minimumDetectionConfidence: Double = 0.15

    init(roomID: UUID, container: AppDependencyContainer) {
        self.roomID = roomID
        self.container = container
        self.camera = container.makeCameraCapture()
        self.startScan = DefaultStartScanSessionUseCase(
            scanRepository: container.scanRepository,
            roomRepository: container.roomRepository
        )
        self.appendScan = DefaultAppendScanImageUseCase(
            scanRepository: container.scanRepository,
            imageStorage: container.imageStorage
        )
        self.completeScan = DefaultCompleteScanSessionUseCase(scanRepository: container.scanRepository)
        self.cancelScan = DefaultCancelScanSessionUseCase(
            scanRepository: container.scanRepository,
            imageStorage: container.imageStorage
        )
        self.saveItem = DefaultSaveItemUseCase(
            itemRepository: container.itemRepository,
            snapshotRepository: container.snapshotRepository,
            imageStorage: container.imageStorage
        )
        self.detection = container.objectDetection
        self.logger = container.logger
    }

    // MARK: Session lifecycle

    func startSession() async {
        guard session == nil, !isStartingSession else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        do {
            try await camera.prepare()
            await camera.start()
            let started = try await startScan.execute(roomID: roomID)
            session = started
        } catch {
            logger.error("Scan start failed", error: error, category: "scan")
            errorAlert = UserFacingError.from(error)
        }
    }

    /// Called when the user backs out mid-flow. Best-effort cleanup:
    /// stops the camera, deletes captured files, and marks the session cancelled.
    func cancelSession() {
        guard let session else {
            Task { await camera.stop() }
            return
        }
        let id = session.id
        self.session = nil
        Task {
            await camera.stop()
            do {
                try await cancelScan.execute(sessionID: id)
            } catch {
                logger.error("Scan cancel failed", error: error, category: "scan")
            }
        }
    }

    /// Called from the review screen "Done" button. Marks the session complete
    /// and stops the camera. Callers should pop the scan destination afterwards.
    /// Returns `true` on success.
    func completeSession() async -> Bool {
        guard let session, !isCompleting else { return false }
        isCompleting = true
        defer { isCompleting = false }
        do {
            _ = try await completeScan.execute(sessionID: session.id)
            await camera.stop()
            return true
        } catch {
            logger.error("Scan complete failed", error: error, category: "scan")
            errorAlert = UserFacingError.from(error)
            return false
        }
    }

    // MARK: Capture

    func capturePhoto() async {
        guard let session, !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let data = try await camera.capturePhoto()
            let updated = try await appendScan.execute(sessionID: session.id, imageData: data)
            self.session = updated

            guard let newPath = updated.capturedImagePaths.last else { return }
            let capture = ScanCapture(
                id: UUID(),
                imagePath: newPath,
                imageData: data,
                detections: [],
                isDetecting: true
            )
            captures.append(capture)
            runDetection(for: capture.id, imageData: data)
        } catch {
            logger.error("Scan capture failed", error: error, category: "scan")
            errorAlert = UserFacingError.from(error)
        }
    }

    private func runDetection(for captureID: UUID, imageData: Data) {
        Task { [detection, minimumDetectionConfidence, logger, weak self] in
            do {
                let results = try await detection.detect(
                    in: imageData,
                    minimumConfidence: minimumDetectionConfidence
                )
                guard let self else { return }
                self.applyDetections(results, to: captureID)
            } catch {
                logger.error("Object detection failed", error: error, category: "scan")
                guard let self else { return }
                self.applyDetections([], to: captureID)
            }
        }
    }

    private func applyDetections(_ results: [DetectedObject], to captureID: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        captures[index].detections = results
        captures[index].isDetecting = false
    }

    // MARK: Review actions

    func deleteCapture(_ captureID: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        let capture = captures.remove(at: index)
        Task { [imageStorage = container.imageStorage] in
            try? await imageStorage.deleteImage(at: capture.imagePath)
        }
    }

    // MARK: Screen transitions

    func goToReview() { screen = .review }
    func goToCapture() { screen = .capture }

    func selectDetection(_ detection: DetectedObject, for captureID: UUID) {
        screen = .saveDetection(captureID: captureID, detection: detection)
    }

    // MARK: Torch

    func toggleTorch() {
        torchOn.toggle()
        Task { [camera, torchOn] in await camera.setTorch(on: torchOn) }
    }

    // MARK: Save-item factory

    func makeSaveItemViewModel(captureID: UUID, detection: DetectedObject) -> ScanSaveItemViewModel {
        let capture = captures.first(where: { $0.id == captureID })
        return ScanSaveItemViewModel(
            roomID: roomID,
            capturedAt: session?.startedAt ?? Date(),
            imageData: capture?.imageData,
            detection: detection,
            confidence: detection.confidence,
            saveItem: saveItem,
            logger: logger
        )
    }
}
