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
    /// Tried first during a scan capture, before falling back to
    /// `objectDetection`'s on-device Vision pipeline — see
    /// `ScanCoordinator.runDetection`.
    let aiItemIdentification: AIItemIdentificationService
    let logger: AppLogger
    let onboardingPreferences: OnboardingPreferences
    let appearanceSettings: AppearanceSettingsStore
    let appLockSettings: AppLockSettingsStore
    let biometricAuthenticator: BiometricAuthenticator
    let authService: AuthService
    /// Phase 4 — Room Sharing. Reads/writes Supabase directly, like
    /// `authService`, rather than going through `syncEngine`: shared-room
    /// data belongs to another account and is never mirrored into this
    /// device's local SwiftData store.
    let roomSharingService: RoomSharingService
    /// Phase 5 — Item Gifting. Same rationale as `roomSharingService`:
    /// direct Supabase reads/writes, no SwiftData mirroring for the gift
    /// rows themselves (the item an accepted gift produces is a normal
    /// owned item afterward and picked up by the recipient's own
    /// `SyncEngine` on their next sync, same as anything else they own).
    let itemGiftingService: ItemGiftingService
    /// Phase 6 — Push Notifications. Registers/unregisters this device's
    /// FCM token against the `device_tokens` table.
    let deviceTokenService: DeviceTokenService
    /// Phase 6 — Push Notifications. Wraps the system permission prompt +
    /// `UIApplication.registerForRemoteNotifications()` so `AppCoordinator`
    /// doesn't import UIKit/UserNotifications directly.
    let pushNotificationPermissionService: PushNotificationPermissionService
    /// First-party product analytics. See `AnalyticsService`'s doc comment
    /// for the rule about never passing user content as a parameter.
    let analytics: AnalyticsService
    /// Push/pull against the Supabase tables from Phase 2. Still constructed
    /// here rather than taken through `init` like everything else, since it
    /// only ever needs the same `modelContainer` this container already has.
    ///
    /// It used to be the one service with no Mock counterpart, on the
    /// grounds that nothing outside a real session ever called it. That's no
    /// longer true: `GiftsViewModel`/`GiftItemViewModel`/`ShareRoomViewModel`
    /// each sync before calling a server-side RPC, so they depend on the
    /// narrower `PendingChangesSyncing` protocol (which this satisfies) and
    /// previews inject `MockPendingChangesSyncing` instead. Kept concretely
    /// typed here because `RootView`/`AppCoordinator` still drive full
    /// syncs directly.
    let syncEngine: SyncEngine

    /// Camera capture wraps AVCaptureSession, which shouldn't be shared across
    /// concurrent scans. The container vends a fresh instance per scan session
    /// via this factory so previews can swap in a mock.
    let makeCameraCapture: @MainActor () -> CameraCaptureService

    init(
        configuration: AppConfiguration = .default,
        modelContainer: ModelContainer,
        imageStorage: ImageStorageService,
        objectDetection: ObjectDetectionService,
        aiItemIdentification: AIItemIdentificationService,
        logger: AppLogger,
        onboardingPreferences: OnboardingPreferences,
        appearanceSettings: AppearanceSettingsStore,
        appLockSettings: AppLockSettingsStore,
        biometricAuthenticator: BiometricAuthenticator,
        authService: AuthService,
        roomSharingService: RoomSharingService,
        itemGiftingService: ItemGiftingService,
        deviceTokenService: DeviceTokenService,
        pushNotificationPermissionService: PushNotificationPermissionService,
        analytics: AnalyticsService,
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
        self.aiItemIdentification = aiItemIdentification
        self.logger = logger
        self.onboardingPreferences = onboardingPreferences
        self.appearanceSettings = appearanceSettings
        self.appLockSettings = appLockSettings
        self.biometricAuthenticator = biometricAuthenticator
        self.authService = authService
        self.roomSharingService = roomSharingService
        self.itemGiftingService = itemGiftingService
        self.deviceTokenService = deviceTokenService
        self.pushNotificationPermissionService = pushNotificationPermissionService
        self.analytics = analytics
        self.syncEngine = SyncEngine(modelContainer: modelContainer)
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
            aiItemIdentification: SupabaseAIItemIdentificationService(),
            logger: OSAppLogger(),
            onboardingPreferences: UserDefaultsOnboardingPreferences(),
            appearanceSettings: AppearanceSettingsStore(),
            appLockSettings: AppLockSettingsStore(),
            biometricAuthenticator: LAContextBiometricAuthenticator(),
            authService: SupabaseAuthService(),
            roomSharingService: SupabaseRoomSharingService(),
            itemGiftingService: SupabaseItemGiftingService(),
            deviceTokenService: SupabaseDeviceTokenService(),
            pushNotificationPermissionService: SystemPushNotificationPermissionService(),
            analytics: FirebaseAnalyticsService(),
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
            aiItemIdentification: MockAIItemIdentificationService(),
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
            roomSharingService: MockRoomSharingService(),
            itemGiftingService: MockItemGiftingService(),
            deviceTokenService: MockDeviceTokenService(),
            pushNotificationPermissionService: MockPushNotificationPermissionService(),
            analytics: MockAnalyticsService(),
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
