//
//  HomeViewModel.swift
//  LastPlace
//
//  Loads the default home + rooms + recent + important items in parallel.
//  Owns nothing UI-specific — the view renders whichever `LoadableState` case
//  is current.
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: LoadableState<HomeDashboardContent> = .idle

    private let fetchDefaultHome: FetchDefaultHomeUseCase
    private let fetchRooms: FetchRoomsUseCase
    private let fetchRecent: FetchRecentItemsUseCase
    private let fetchImportant: FetchImportantItemsUseCase
    private let roomSharingService: RoomSharingService
    private let configuration: AppConfiguration
    private let logger: AppLogger

    init(
        fetchDefaultHome: FetchDefaultHomeUseCase,
        fetchRooms: FetchRoomsUseCase,
        fetchRecent: FetchRecentItemsUseCase,
        fetchImportant: FetchImportantItemsUseCase,
        roomSharingService: RoomSharingService,
        configuration: AppConfiguration,
        logger: AppLogger
    ) {
        self.fetchDefaultHome = fetchDefaultHome
        self.fetchRooms = fetchRooms
        self.fetchRecent = fetchRecent
        self.fetchImportant = fetchImportant
        self.roomSharingService = roomSharingService
        self.configuration = configuration
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading

        do {
            let home = try await fetchDefaultHome.execute()
            async let roomsTask = fetchRooms.execute(homeID: home.id)
            async let recentTask = fetchRecent.execute(limit: configuration.recentItemsLimit)
            async let importantTask = fetchImportant.execute()

            // Not in the `try await` tuple above, and deliberately
            // non-throwing: every other fetch here reads local SwiftData
            // and succeeds offline, but shared rooms can only come from
            // Supabase. Letting a dead network take the whole dashboard to
            // `.failed` would mean someone with one shared room loses
            // access to all of their *own* rooms the moment they walk into
            // a lift. Degrades to an absent section instead.
            async let sharedTask = loadSharedRooms()

            let (rooms, recent, important) = try await (roomsTask, recentTask, importantTask)

            let content = HomeDashboardContent(
                home: home,
                rooms: rooms,
                recentItems: recent,
                importantItems: important,
                sharedRooms: await sharedTask
            )
            state = .loaded(content)
        } catch {
            logger.error("Home dashboard load failed", error: error, category: "home")
            state = .failed(UserFacingError.from(error))
        }
    }

    /// Accepted incoming shares, enriched with each room and its owner's
    /// name. Pending invites are excluded -- those still need an
    /// accept/decline decision, which belongs on Settings → Shared Rooms,
    /// not mixed into a browsing surface.
    ///
    /// Failures are logged and swallowed *per share* as well as overall, so
    /// one unreadable room (revoked mid-flight, owner deleted their
    /// account) doesn't take the rest of the section down with it.
    private func loadSharedRooms() async -> [HomeSharedRoom] {
        let roomSharingService = self.roomSharingService
        do {
            let accepted = try await roomSharingService.incomingShares().filter(\.isAccepted)
            guard !accepted.isEmpty else { return [] }

            return await withTaskGroup(of: HomeSharedRoom?.self) { group in
                for share in accepted {
                    group.addTask {
                        guard let detail = try? await roomSharingService.fetchSharedRoomDetail(
                            roomID: share.roomID
                        ) else { return nil }
                        let profile = try? await roomSharingService.fetchProfile(userID: share.ownerID)
                        return HomeSharedRoom(
                            room: detail.room,
                            ownerID: share.ownerID,
                            ownerLabel: profile?.displayLabel
                        )
                    }
                }
                var results: [HomeSharedRoom] = []
                for await value in group {
                    if let value { results.append(value) }
                }
                // Task groups complete out of order; sort so the section
                // doesn't reshuffle itself between refreshes.
                return results.sorted { $0.room.name.localizedCaseInsensitiveCompare($1.room.name) == .orderedAscending }
            }
        } catch {
            logger.warning(
                "Loading shared rooms for Home failed; section hidden this pass",
                category: "home"
            )
            return []
        }
    }

    func refresh() async {
        await load()
    }
}
