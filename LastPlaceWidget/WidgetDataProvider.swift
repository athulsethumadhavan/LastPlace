//
//  WidgetDataProvider.swift
//  LastPlaceWidget
//
//  Minimal, widget-only data access. Deliberately doesn't reuse
//  `AppDependencyContainer` — that composition root pulls in Vision,
//  AVFoundation, and MainActor-only preference stores the widget has no use
//  for, and a widget extension has a tight memory budget where that weight
//  actually matters. This talks to the same repositories and use cases the
//  app uses (see target-membership notes in the setup instructions), just
//  wired up directly against `SwiftDataContainerFactory.makeWidgetContainer()`
//  instead.
//

import Foundation
import SwiftData

struct WidgetItemInfo: Identifiable, Sendable {
    let id: UUID
    let name: String
    let locationDescription: String
    let roomName: String
}

struct WidgetChecklistProgress: Sendable {
    let checklistName: String
    let completedCount: Int
    let totalCount: Int
    let remainingTitles: [String]
}

enum WidgetDataProvider {
    private static func makeContainer() throws -> ModelContainer {
        try SwiftDataContainerFactory.makeWidgetContainer()
    }

    /// Prefers items the user explicitly starred important — those are the
    /// ones most worth a glance from the home screen — falling back to
    /// recents so the widget still has something to show for a household
    /// that hasn't starred anything yet.
    static func fetchHighlightItems(limit: Int = 6) async -> [WidgetItemInfo] {
        let important = await fetchImportantItems()
        if !important.isEmpty { return Array(important.prefix(limit)) }
        return await fetchRecentItems(limit: limit)
    }

    static func fetchRecentItems(limit: Int = 6) async -> [WidgetItemInfo] {
        guard let container = try? makeContainer() else { return [] }
        let itemRepository = SwiftDataItemRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let fetchRecent = DefaultFetchRecentItemsUseCase(itemRepository: itemRepository)

        guard let items = try? await fetchRecent.execute(limit: limit) else { return [] }
        return await withRoomNames(items, roomRepository: roomRepository)
    }

    static func fetchImportantItems() async -> [WidgetItemInfo] {
        guard let container = try? makeContainer() else { return [] }
        let itemRepository = SwiftDataItemRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let fetchImportant = DefaultFetchImportantItemsUseCase(itemRepository: itemRepository)

        guard let items = try? await fetchImportant.execute() else { return [] }
        return await withRoomNames(items, roomRepository: roomRepository)
    }

    private static func withRoomNames(
        _ items: [StoredItem],
        roomRepository: RoomRepository
    ) async -> [WidgetItemInfo] {
        var roomNamesByID: [UUID: String] = [:]
        var results: [WidgetItemInfo] = []
        for item in items {
            let roomName: String
            if let cached = roomNamesByID[item.roomID] {
                roomName = cached
            } else if let room = try? await roomRepository.fetchRoom(roomID: item.roomID) {
                roomName = room.name
                roomNamesByID[item.roomID] = room.name
            } else {
                roomName = "Unknown room"
            }
            results.append(
                WidgetItemInfo(id: item.id, name: item.name, locationDescription: item.locationDescription, roomName: roomName)
            )
        }
        return results
    }

    /// Picks the checklist most worth showing: the first one (in the
    /// repository's normal newest-first order) that still has unchecked
    /// items, so the widget is useful right when you're about to leave
    /// rather than showing a checklist you already finished. Falls back to
    /// the most recent checklist if every one is complete, so the widget
    /// isn't blank for someone who's fully packed.
    static func fetchActiveChecklistProgress() async -> WidgetChecklistProgress? {
        guard let container = try? makeContainer() else { return nil }
        let checklistRepository = SwiftDataChecklistRepository(modelContainer: container)
        let fetchChecklists = DefaultFetchChecklistsUseCase(checklistRepository: checklistRepository)
        let fetchDetail = DefaultFetchChecklistDetailUseCase(checklistRepository: checklistRepository)

        guard let checklists = try? await fetchChecklists.execute(), !checklists.isEmpty else { return nil }

        for checklist in checklists {
            guard let detail = try? await fetchDetail.execute(id: checklist.id) else { continue }
            if detail.totalCount > 0 && detail.completedCount < detail.totalCount {
                let remaining = detail.entries
                    .filter { !$0.isCompleted }
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .prefix(3)
                    .map(\.title)
                return WidgetChecklistProgress(
                    checklistName: checklist.name,
                    completedCount: detail.completedCount,
                    totalCount: detail.totalCount,
                    remainingTitles: Array(remaining)
                )
            }
        }

        guard let mostRecent = checklists.first,
              let detail = try? await fetchDetail.execute(id: mostRecent.id) else { return nil }
        return WidgetChecklistProgress(
            checklistName: mostRecent.name,
            completedCount: detail.completedCount,
            totalCount: detail.totalCount,
            remainingTitles: []
        )
    }

    static func fetchSummary() async -> DataSummary? {
        guard let container = try? makeContainer() else { return nil }
        let fetchSummary = DefaultFetchDataSummaryUseCase(
            homeRepository: SwiftDataHomeRepository(modelContainer: container),
            roomRepository: SwiftDataRoomRepository(modelContainer: container),
            itemRepository: SwiftDataItemRepository(modelContainer: container),
            checklistRepository: SwiftDataChecklistRepository(modelContainer: container)
        )
        return try? await fetchSummary.execute()
    }
}
