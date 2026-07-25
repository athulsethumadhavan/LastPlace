//
//  GiftsViewModel.swift
//  LastPlace
//
//  Recipient + sender side of Phase 5 gifting in one screen: gifts sent to
//  you (accept into a room of your own, or decline) and gifts you've sent
//  (cancel while still pending). Reads live from Supabase via
//  `ItemGiftingService` — nothing here touches SwiftData directly; an
//  accepted gift's resulting item is picked up locally the next time this
//  device's own `SyncEngine` runs.
//

import Foundation
import Observation

struct IncomingGiftSummary: Identifiable, Sendable {
    let gift: ItemGift
    let senderProfile: SharingProfile?
    var id: UUID { gift.id }
}

struct OutgoingGiftSummary: Identifiable, Sendable {
    let gift: ItemGift
    let recipientProfile: SharingProfile?
    var id: UUID { gift.id }
}

struct GiftsContent: Sendable {
    let incoming: [IncomingGiftSummary]
    let outgoing: [OutgoingGiftSummary]
}

@Observable
@MainActor
final class GiftsViewModel {
    private(set) var state: LoadableState<GiftsContent> = .idle
    private(set) var mutatingGiftID: UUID?
    var actionError: UserFacingError?

    private let itemGiftingService: ItemGiftingService
    private let homeRepository: HomeRepository
    private let roomRepository: RoomRepository
    /// Only used by `accept(_:intoRoomID:)`, to write the newly-created
    /// item and its photo into local storage the moment it's accepted --
    /// see that method's doc comment for why this doesn't wait for the
    /// next `SyncEngine` pass.
    private let itemRepository: ItemRepository
    private let imageStorage: ImageStorageService
    private let logger: AppLogger

    init(
        itemGiftingService: ItemGiftingService,
        homeRepository: HomeRepository,
        roomRepository: RoomRepository,
        itemRepository: ItemRepository,
        imageStorage: ImageStorageService,
        logger: AppLogger
    ) {
        self.itemGiftingService = itemGiftingService
        self.homeRepository = homeRepository
        self.roomRepository = roomRepository
        self.itemRepository = itemRepository
        self.imageStorage = imageStorage
        self.logger = logger
    }

    var pendingIncoming: [IncomingGiftSummary] {
        (state.value?.incoming ?? []).filter { $0.gift.status == .pending }
    }

    var resolvedIncoming: [IncomingGiftSummary] {
        (state.value?.incoming ?? []).filter { $0.gift.status != .pending }
    }

    var outgoing: [OutgoingGiftSummary] {
        state.value?.outgoing ?? []
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        await refresh()
    }

    /// Destination rooms for the accept flow's room picker — this device's
    /// own inventory, same lookup `CreateRoomHost` uses.
    func fetchRoomsForAccept() async throws -> [Room] {
        let home = try await homeRepository.fetchDefaultHome()
        return try await roomRepository.fetchRooms(homeID: home.id)
    }

    /// Accepting doesn't just create the item in Supabase — it also writes
    /// the item and its photo into this device's own local storage right
    /// away. Without this, the new item would only exist remotely until
    /// the next `SyncEngine.sync()` pass (next sign-in or app foreground),
    /// so it'd be invisible in Home/Search the moment you accept it.
    /// `itemRepository.create` always marks the row `.pendingUpsert`, so
    /// the next sync harmlessly re-upserts identical data — not worth a
    /// special "already synced" path just to skip that.
    func accept(_ giftID: UUID, intoRoomID roomID: UUID) {
        guard mutatingGiftID == nil else { return }
        mutatingGiftID = giftID
        Task {
            defer { mutatingGiftID = nil }
            do {
                let (item, imageData) = try await itemGiftingService.acceptGift(giftID, intoRoomID: roomID)
                if let imageData, let imagePath = item.imagePath {
                    try await imageStorage.restoreImageData(imageData, at: imagePath)
                }
                _ = try await itemRepository.create(item)
                await refresh()
            } catch {
                logger.error("Accepting gift failed", error: error, category: "gifting")
                actionError = UserFacingError.from(error)
            }
        }
    }

    func decline(_ giftID: UUID) {
        guard mutatingGiftID == nil else { return }
        mutatingGiftID = giftID
        Task {
            defer { mutatingGiftID = nil }
            do {
                try await itemGiftingService.declineGift(giftID)
                await refresh()
            } catch {
                logger.error("Declining gift failed", error: error, category: "gifting")
                actionError = UserFacingError.from(error)
            }
        }
    }

    func cancel(_ giftID: UUID) {
        guard mutatingGiftID == nil else { return }
        mutatingGiftID = giftID
        Task {
            defer { mutatingGiftID = nil }
            do {
                try await itemGiftingService.cancelGift(giftID)
                await refresh()
            } catch {
                logger.error("Cancelling gift failed", error: error, category: "gifting")
                actionError = UserFacingError.from(error)
            }
        }
    }

    private func refresh() async {
        do {
            async let incomingTask = itemGiftingService.incomingGifts()
            async let outgoingTask = itemGiftingService.outgoingGifts()
            let (incomingGifts, outgoingGifts) = try await (incomingTask, outgoingTask)

            let incomingResult = await summarize(incomingGifts)
            let outgoingResult = await summarize(outgoingGifts, ownerOf: \.toUserID)

            state = .loaded(GiftsContent(
                incoming: incomingResult.sorted { $0.gift.createdAt > $1.gift.createdAt },
                outgoing: outgoingResult.sorted { $0.gift.createdAt > $1.gift.createdAt }
            ))
        } catch {
            logger.error("Loading gifts failed", error: error, category: "gifting")
            state = .failed(UserFacingError.from(error))
        }
    }

    private func summarize(_ gifts: [ItemGift]) async -> [IncomingGiftSummary] {
        let itemGiftingService = self.itemGiftingService
        return await withTaskGroup(of: IncomingGiftSummary.self) { group in
            for gift in gifts {
                group.addTask {
                    let profile = try? await itemGiftingService.fetchProfile(userID: gift.fromUserID)
                    return IncomingGiftSummary(gift: gift, senderProfile: profile)
                }
            }
            var results: [IncomingGiftSummary] = []
            for await summary in group { results.append(summary) }
            return results
        }
    }

    private func summarize(_ gifts: [ItemGift], ownerOf keyPath: KeyPath<ItemGift, UUID>) async -> [OutgoingGiftSummary] {
        let itemGiftingService = self.itemGiftingService
        return await withTaskGroup(of: OutgoingGiftSummary.self) { group in
            for gift in gifts {
                group.addTask {
                    let profile = try? await itemGiftingService.fetchProfile(userID: gift[keyPath: keyPath])
                    return OutgoingGiftSummary(gift: gift, recipientProfile: profile)
                }
            }
            var results: [OutgoingGiftSummary] = []
            for await summary in group { results.append(summary) }
            return results
        }
    }
}
