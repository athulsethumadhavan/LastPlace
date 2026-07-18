//
//  FamilyFindViewModel.swift
//  LastPlace
//
//  Two independent pieces of state, not one `LoadableState` — "my home"
//  (share status) and "shared with me" (what others have shared) load and
//  fail separately, and a failure in one shouldn't blank out the other.
//

import Foundation
import Observation
import CloudKit

@Observable
@MainActor
final class FamilyFindViewModel {
    private(set) var myHomeState: LoadableState<Home> = .idle
    private(set) var isMyHomeShared = false
    private(set) var sharedHomesState: LoadableState<[SharedHomeSnapshot]> = .idle
    private(set) var isPreparingShare = false
    var error: UserFacingError?

    /// Set once `shareOrRefresh` succeeds; the view watches this to present
    /// `CloudSharingViewRepresentable` as a sheet.
    var pendingShare: CKShare?

    private let fetchDefaultHome: FetchDefaultHomeUseCase
    private let roomRepository: RoomRepository
    private let itemRepository: ItemRepository
    private let homeSharingService: HomeSharingService
    private let logger: AppLogger

    var sharingContainer: CKContainer { homeSharingService.container }

    init(
        fetchDefaultHome: FetchDefaultHomeUseCase,
        roomRepository: RoomRepository,
        itemRepository: ItemRepository,
        homeSharingService: HomeSharingService,
        logger: AppLogger
    ) {
        self.fetchDefaultHome = fetchDefaultHome
        self.roomRepository = roomRepository
        self.itemRepository = itemRepository
        self.homeSharingService = homeSharingService
        self.logger = logger
    }

    func loadMyHome() async {
        if case .loading = myHomeState { return }
        myHomeState = .loading
        do {
            let home = try await fetchDefaultHome.execute()
            isMyHomeShared = try await homeSharingService.isShared(homeID: home.id)
            myHomeState = .loaded(home)
        } catch {
            logger.error("Family Find: failed to load home", error: error, category: "family-find")
            myHomeState = .failed(UserFacingError.from(error))
        }
    }

    func loadSharedHomes() async {
        if case .loading = sharedHomesState { return }
        sharedHomesState = .loading
        do {
            let snapshots = try await homeSharingService.fetchSharedSnapshots()
            sharedHomesState = snapshots.isEmpty ? .empty : .loaded(snapshots)
        } catch {
            logger.error("Family Find: failed to load shared homes", error: error, category: "family-find")
            sharedHomesState = .failed(UserFacingError.from(error))
        }
    }

    /// Builds the current snapshot from live data and publishes it,
    /// setting `pendingShare` so the view can present the native share
    /// sheet. Safe to call again for an already-shared home — it just
    /// refreshes the published data and re-presents the same share.
    func shareMyHome() async {
        guard case .loaded(let home) = myHomeState, !isPreparingShare else { return }
        isPreparingShare = true
        error = nil
        defer { isPreparingShare = false }

        do {
            let rooms = try await roomRepository.fetchRooms(homeID: home.id)
            var items: [StoredItem] = []
            for room in rooms {
                items.append(contentsOf: try await itemRepository.fetchItems(roomID: room.id))
            }
            let share = try await homeSharingService.shareOrRefresh(home: home, rooms: rooms, items: items)
            isMyHomeShared = true
            pendingShare = share
        } catch {
            logger.error("Family Find: failed to publish share", error: error, category: "family-find")
            self.error = UserFacingError.from(error)
        }
    }

    func stopSharingMyHome() async {
        guard case .loaded(let home) = myHomeState else { return }
        do {
            try await homeSharingService.stopSharing(homeID: home.id)
            isMyHomeShared = false
        } catch {
            logger.error("Family Find: failed to stop sharing", error: error, category: "family-find")
            self.error = UserFacingError.from(error)
        }
    }
}
