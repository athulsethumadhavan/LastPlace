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

import CoreGraphics
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
        /// What the review screen shows. Stays empty, with `isDetecting`
        /// true, until recognition settles -- see `runDetection`.
        var detections: [DetectedObject]
        var isDetecting: Bool
        /// Vision's answer, held back rather than displayed.
        ///
        /// Both recognisers still run in parallel, but showing Vision's
        /// result the moment it arrived meant the label visibly changed
        /// under the user a second or two later when the AI replied, which
        /// reads as a glitch rather than an upgrade. Staging it here lets
        /// the UI show one loader and then one answer: the AI's if it
        /// succeeds, this if it doesn't.
        var stagedVisionResults: [DetectedObject]?
        /// Set when the AI call finished without a usable name. Needed
        /// because the two tasks can finish in either order -- if AI fails
        /// before Vision returns, there's nothing to fall back to yet, so
        /// the Vision task publishes when it arrives instead.
        var aiDidFail: Bool = false
        /// The detection the person picked, if any. Drives the Proceed
        /// button on the review screen.
        var selectedDetectionID: UUID?
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
    /// How many items have been saved during this scan session -- reported
    /// in the `.scanCompleted` analytics event, to show how many captures
    /// actually turn into saved items rather than getting abandoned.
    private(set) var itemsSavedCount: Int = 0

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
    private let aiIdentification: AIItemIdentificationService
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
        self.aiIdentification = container.aiItemIdentification
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
            container.analytics.log(.scanCompleted(
                captureCount: captures.count,
                itemsSaved: itemsSavedCount
            ))
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

    /// Runs both recognisers, but does not make the user wait for both.
    ///
    /// On-device Vision returns in roughly 200ms, so its result is shown
    /// straight away and the capture stops looking "busy". The cloud AI call
    /// runs concurrently and, if it produces a usable name, replaces the
    /// Vision label a moment later.
    ///
    /// This used to be sequential -- await AI, fall back to Vision only on
    /// failure -- which meant a slow or failing AI call blocked the UI for
    /// its entire timeout before *any* label appeared. That's the worst of
    /// both: the person stares at a spinner and then gets the weaker answer
    /// anyway. Running them in parallel means AI latency only ever delays
    /// the upgrade, never the first result, and an AI outage degrades to
    /// "Vision-quality names, instantly" rather than "nothing for a minute".
    private func runDetection(for captureID: UUID, imageData: Data) {
        // Vision: fast, but staged rather than shown -- see `stageVisionResults`.
        Task { [detection, minimumDetectionConfidence, logger, weak self] in
            do {
                let results = try await detection.detect(
                    in: imageData,
                    minimumConfidence: minimumDetectionConfidence
                )
                guard let self else { return }
                self.stageVisionResults(results, to: captureID)
            } catch {
                logger.error("Object detection failed", error: error, category: "scan")
                guard let self else { return }
                self.stageVisionResults([], to: captureID)
            }
        }

        // AI: slow path, upgrades the label in place when it lands.
        Task { [aiIdentification, logger, weak self] in
            // Deliberately do/catch rather than `try?`: silently keeping the
            // Vision label is right for the *user*, but it also made the AI
            // path undiagnosable -- a missing API key, an expired session
            // and "the model saw nothing" all looked identical from
            // outside. Log the reason, keep what Vision gave us.
            do {
                let aiResult = try await aiIdentification.identifyItem(in: imageData)
                let trimmedName = aiResult.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    logger.warning(
                        "AI identification returned an empty name; falling back to Vision",
                        category: "scan"
                    )
                    guard let self else { return }
                    self.markAIFailed(for: captureID)
                    return
                }
                guard let self else { return }
                self.applyAIDetection(
                    DetectedObject(
                        label: trimmedName,
                        confidence: aiResult.confidence,
                        boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                        suggestedCategory: aiResult.category
                    ),
                    to: captureID
                )
            } catch {
                logger.error(
                    "AI identification failed; falling back to Vision",
                    error: error,
                    category: "scan"
                )
                guard let self else { return }
                self.markAIFailed(for: captureID)
            }
        }
    }

    /// Holds Vision's answer without displaying it. Only publishes if the
    /// AI has already given up -- otherwise the loader stays visible until
    /// the AI replies, so the user sees one result rather than watching the
    /// label change under them.
    private func stageVisionResults(_ results: [DetectedObject], to captureID: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        captures[index].stagedVisionResults = results
        if captures[index].aiDidFail {
            captures[index].detections = results
            captures[index].isDetecting = false
            autoSelectSingleResult(at: index)
        }
    }

    /// The AI's single, more specific name. Wins outright: it publishes
    /// immediately without waiting for Vision, since there's nothing better
    /// to wait for.
    private func applyAIDetection(_ detection: DetectedObject, to captureID: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        captures[index].detections = [detection]
        captures[index].isDetecting = false
        autoSelectSingleResult(at: index)
    }

    /// The AI produced nothing usable. Publishes Vision's answer if it has
    /// already arrived; otherwise records the failure so
    /// `stageVisionResults` publishes as soon as it does. Between them the
    /// two cover both completion orders without either task needing to know
    /// about the other.
    private func markAIFailed(for captureID: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        captures[index].aiDidFail = true
        if let staged = captures[index].stagedVisionResults {
            captures[index].detections = staged
            captures[index].isDetecting = false
            autoSelectSingleResult(at: index)
        }
    }

    /// Pre-selects the result when there's only one, so Proceed appears
    /// without asking for a tap that has no alternative. The AI path always
    /// returns exactly one name, so this is the normal case now.
    ///
    /// Skipped if anything is already selected. Selection is exclusive
    /// across captures, so without that guard a second photo resolving
    /// would silently steal the selection from the first -- and with
    /// several captures resolving at different times, whichever finished
    /// last would win, which is arbitrary from the user's point of view.
    /// A deliberate tap can still move it anywhere.
    private func autoSelectSingleResult(at index: Int) {
        guard captures[index].detections.count == 1 else { return }
        guard captures.allSatisfy({ $0.selectedDetectionID == nil }) else { return }
        captures[index].selectedDetectionID = captures[index].detections.first?.id
    }

    /// Toggles which detection the person has picked. Tapping the selected
    /// one again clears it, so a mis-tap doesn't strand them with a Proceed
    /// button they didn't mean to enable.
    func toggleSelection(_ detectionID: UUID, for captureID: UUID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        let isDeselecting = captures[index].selectedDetectionID == detectionID

        // Exclusive across the whole session, not just within one capture:
        // Proceed saves a single item, so two highlighted chips on different
        // photos would leave it ambiguous which one it acts on.
        for i in captures.indices {
            captures[i].selectedDetectionID = nil
        }
        if !isDeselecting {
            captures[index].selectedDetectionID = detectionID
        }
    }

    /// The detection the person picked, if any, across all captures.
    /// Drives whether Proceed is shown and what it opens.
    var selectedDetection: (captureID: UUID, detection: DetectedObject)? {
        for capture in captures {
            if let selectedID = capture.selectedDetectionID,
               let match = capture.detections.first(where: { $0.id == selectedID }) {
                return (capture.id, match)
            }
        }
        return nil
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

    /// Called by `ScanSaveItemView` after a successful save. The item-level
    /// `.itemSaved` event is logged by `ScanSaveItemViewModel` itself; this
    /// only keeps the per-session tally for `.scanCompleted`.
    func recordItemSaved() { itemsSavedCount += 1 }

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
            analytics: container.analytics,
            logger: logger
        )
    }
}
