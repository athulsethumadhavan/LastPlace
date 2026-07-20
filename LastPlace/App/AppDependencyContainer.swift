//
//  AppDependencyContainer.swift
//  LastPlace
//
//  Composition root. Owns the `ModelContainer`, all repository actors, cross-
//  cutting services, and vends per-feature dependency bundles that coordinators
//  and view models consume. Nothing else in the app is allowed to reach for a
//  singleton — every dependency travels through here.
//

import Foundation
import SwiftData

@MainActor
final class AppDependencyContainer {
    let configuration: AppConfiguration
    let modelContainer: ModelContainer

    let homeRepository: HomeRepository
    let roomRepository: RoomRepository
    let itemRepository: ItemRepository
    let snapshotRepository: SnapshotRepository
    let scanRepository: ScanRepository
    let checklistRepository: ChecklistRepository

    let imageStorage: ImageStorageService
    let objectDetection: ObjectDetectionService
    let logger: AppLogger
    let onboardingPreferences: OnboardingPreferences
    let appearanceSettings: AppearanceSettingsStore
    let appLockSettings: AppLockSettingsStore
    let biometricAuthenticator: BiometricAuthenticator
    let authService: AuthService

    /// Camera capture wraps AVCaptureSession, which shouldn't be shared across
    /// concurrent scans. The container vends a fresh instance per scan session
    /// via this factory so previews can swap in a mock.
    let makeCameraCapture: @MainActor () -> CameraCaptureService

    init(
        configuration: AppConfiguration = .default,
        modelContainer: ModelContainer,
        imageStorage: ImageStorageService,
        objectDetection: ObjectDetectionService,
        logger: AppLogger,
        onboardingPreferences: OnboardingPreferences,
        appearanceSettings: AppearanceSettingsStore,
        appLockSettings: AppLockSettingsStore,
        biometricAuthenticator: BiometricAuthenticator,
        authService: AuthService,
        homeRepository: HomeRepository,
        roomRepository: RoomRepository,
        itemRepository: ItemRepository,
        snapshotRepository: SnapshotRepository,
        scanRepository: ScanRepository,
        checklistRepository: ChecklistRepository,
        makeCameraCapture: @escaping @MainActor () -> CameraCaptureService
    ) {
        self.configuration = configuration
        self.modelContainer = modelContainer
        self.imageStorage = imageStorage
        self.objectDetection = objectDetection
        self.logger = logger
        self.onboardingPreferences = onboardingPreferences
        self.appearanceSettings = appearanceSettings
        self.appLockSettings = appLockSettings
        self.biometricAuthenticator = biometricAuthenticator
        self.authService = authService
        self.homeRepository = homeRepository
        self.roomRepository = roomRepository
        self.itemRepository = itemRepository
        self.snapshotRepository = snapshotRepository
        self.scanRepository = scanRepository
        self.checklistRepository = checklistRepository
        self.makeCameraCapture = makeCameraCapture
    }

    /// Production wiring — disk-backed SwiftData, file-backed images,
    /// `UserDefaults` onboarding flag, and the OS logger.
    static func makeDefault() throws -> AppDependencyContainer {
        let modelContainer = try SwiftDataContainerFactory.makeContainer()
        SwiftDataContainerFactory.backfillRelationships(in: modelContainer)
        let imageStorage = try FileImageStorageService()

        return AppDependencyContainer(
            modelContainer: modelContainer,
            imageStorage: imageStorage,
            objectDetection: VisionObjectDetectionService(),
            logger: OSAppLogger(),
            onboardingPreferences: UserDefaultsOnboardingPreferences(),
            appearanceSettings: AppearanceSettingsStore(),
            appLockSettings: AppLockSettingsStore(),
            biometricAuthenticator: LAContextBiometricAuthenticator(),
            authService: SupabaseAuthService(),
            homeRepository: SwiftDataHomeRepository(modelContainer: modelContainer),
            roomRepository: SwiftDataRoomRepository(modelContainer: modelContainer),
            itemRepository: SwiftDataItemRepository(modelContainer: modelContainer),
            snapshotRepository: SwiftDataSnapshotRepository(modelContainer: modelContainer),
            scanRepository: SwiftDataScanRepository(modelContainer: modelContainer),
            checklistRepository: SwiftDataChecklistRepository(modelContainer: modelContainer),
            makeCameraCapture: { AVFoundationCameraCaptureService() }
        )
    }

    /// In-memory wiring for previews and integration tests.
    static func makePreview(onboardingCompleted: Bool = true) throws -> AppDependencyContainer {
        let modelContainer = try SwiftDataContainerFactory.makeInMemoryContainer()
        return AppDependencyContainer(
            modelContainer: modelContainer,
            imageStorage: MockImageStorageService(),
            objectDetection: MockObjectDetectionService(),
            logger: OSAppLogger(),
            onboardingPreferences: InMemoryOnboardingPreferences(completed: onboardingCompleted),
            appearanceSettings: AppearanceSettingsStore(
                defaults: UserDefaults(suiteName: "com.lastplace.preview") ?? .standard
            ),
            appLockSettings: AppLockSettingsStore(
                defaults: UserDefaults(suiteName: "com.lastplace.preview") ?? .standard
            ),
            biometricAuthenticator: MockBiometricAuthenticator(),
            authService: MockAuthService(),
            homeRepository: SwiftDataHomeRepository(modelContainer: modelContainer),
            roomRepository: SwiftDataRoomRepository(modelContainer: modelContainer),
            itemRepository: SwiftDataItemRepository(modelContainer: modelContainer),
            snapshotRepository: SwiftDataSnapshotRepository(modelContainer: modelContainer),
            scanRepository: SwiftDataScanRepository(modelContainer: modelContainer),
            checklistRepository: SwiftDataChecklistRepository(modelContainer: modelContainer),
            makeCameraCapture: { MockCameraCaptureService() }
        )
    }
}
