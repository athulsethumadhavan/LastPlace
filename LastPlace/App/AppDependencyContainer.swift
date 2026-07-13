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
    let logger: AppLogger
    let onboardingPreferences: OnboardingPreferences

    init(
        configuration: AppConfiguration = .default,
        modelContainer: ModelContainer,
        imageStorage: ImageStorageService,
        logger: AppLogger,
        onboardingPreferences: OnboardingPreferences,
        homeRepository: HomeRepository,
        roomRepository: RoomRepository,
        itemRepository: ItemRepository,
        snapshotRepository: SnapshotRepository,
        scanRepository: ScanRepository,
        checklistRepository: ChecklistRepository
    ) {
        self.configuration = configuration
        self.modelContainer = modelContainer
        self.imageStorage = imageStorage
        self.logger = logger
        self.onboardingPreferences = onboardingPreferences
        self.homeRepository = homeRepository
        self.roomRepository = roomRepository
        self.itemRepository = itemRepository
        self.snapshotRepository = snapshotRepository
        self.scanRepository = scanRepository
        self.checklistRepository = checklistRepository
    }

    /// Production wiring — disk-backed SwiftData, file-backed images,
    /// `UserDefaults` onboarding flag, and the OS logger.
    static func makeDefault() throws -> AppDependencyContainer {
        let modelContainer = try SwiftDataContainerFactory.makeContainer()
        let imageStorage = try FileImageStorageService()

        return AppDependencyContainer(
            modelContainer: modelContainer,
            imageStorage: imageStorage,
            logger: OSAppLogger(),
            onboardingPreferences: UserDefaultsOnboardingPreferences(),
            homeRepository: SwiftDataHomeRepository(modelContainer: modelContainer),
            roomRepository: SwiftDataRoomRepository(modelContainer: modelContainer),
            itemRepository: SwiftDataItemRepository(modelContainer: modelContainer),
            snapshotRepository: SwiftDataSnapshotRepository(modelContainer: modelContainer),
            scanRepository: SwiftDataScanRepository(modelContainer: modelContainer),
            checklistRepository: SwiftDataChecklistRepository(modelContainer: modelContainer)
        )
    }

    /// In-memory wiring for previews and integration tests.
    static func makePreview(onboardingCompleted: Bool = true) throws -> AppDependencyContainer {
        let modelContainer = try SwiftDataContainerFactory.makeInMemoryContainer()
        return AppDependencyContainer(
            modelContainer: modelContainer,
            imageStorage: MockImageStorageService(),
            logger: OSAppLogger(),
            onboardingPreferences: InMemoryOnboardingPreferences(completed: onboardingCompleted),
            homeRepository: SwiftDataHomeRepository(modelContainer: modelContainer),
            roomRepository: SwiftDataRoomRepository(modelContainer: modelContainer),
            itemRepository: SwiftDataItemRepository(modelContainer: modelContainer),
            snapshotRepository: SwiftDataSnapshotRepository(modelContainer: modelContainer),
            scanRepository: SwiftDataScanRepository(modelContainer: modelContainer),
            checklistRepository: SwiftDataChecklistRepository(modelContainer: modelContainer)
        )
    }
}
