//
//  SharedItemDetailViewModel.swift
//  LastPlace
//
//  An item inside a room someone else shared with you. Replaces the
//  read-only sheet this used to be: a viewer can now record where the item
//  is, which is the one thing a second person in the same house actually
//  needs to do.
//
//  Everything here is read live from Supabase and never written into local
//  SwiftData. That isn't a style preference -- `SyncEngine` pushes every row
//  in the local store as owned by `auth.uid()`, so caching another account's
//  item locally would make this device try to claim it. See the note atop
//  `RoomSharingService`.
//
//  What a viewer may change is enforced by the database, not by this file:
//  `update_shared_item_location` writes exactly `location_description`,
//  `last_seen_at` and `updated_at`. Name, notes, category, importance,
//  deletion and re-sharing stay with the owner.
//

import Foundation
import Observation

struct SharedItemDetailContent: Sendable {
    let item: StoredItem
    let history: [SharedItemHistoryEntry]
    let ownerProfile: SharingProfile?
}

@Observable
@MainActor
final class SharedItemDetailViewModel {
    let itemID: UUID
    let roomID: UUID
    let ownerID: UUID

    private(set) var state: LoadableState<SharedItemDetailContent> = .idle
    private(set) var isSaving = false
    var actionError: UserFacingError?

    /// Set once loaded, so history entries can say "you" instead of
    /// repeating the viewer's own name back at them.
    private(set) var currentUserID: UUID?

    private let roomSharingService: RoomSharingService
    private let authService: AuthService
    private let logger: AppLogger

    init(
        itemID: UUID,
        roomID: UUID,
        ownerID: UUID,
        roomSharingService: RoomSharingService,
        authService: AuthService,
        logger: AppLogger
    ) {
        self.itemID = itemID
        self.roomID = roomID
        self.ownerID = ownerID
        self.roomSharingService = roomSharingService
        self.authService = authService
        self.logger = logger
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        await reload()
    }

    /// Separate from `load()` so a save can refresh without flashing the
    /// whole screen back to a spinner.
    private func reload() async {
        do {
            async let detailTask = roomSharingService.fetchSharedRoomDetail(roomID: roomID)
            async let historyTask = roomSharingService.sharedItemHistory(itemID: itemID)
            async let profileTask = roomSharingService.fetchProfile(userID: ownerID)
            async let userTask = authService.currentUser

            let (detail, history, profile, user) = try await (
                detailTask, historyTask, profileTask, userTask
            )
            currentUserID = user?.id

            // The room read is the source of truth for the item rather than
            // a separate single-row fetch: it's the same query the room
            // screen already makes, and a missing item here means the owner
            // deleted it while this screen was open -- which is a real state
            // worth reporting, not an error to retry.
            guard let item = detail.items.first(where: { $0.id == itemID }) else {
                state = .failed(
                    UserFacingError(
                        title: "Item no longer available",
                        message: "The owner removed this item from the room."
                    )
                )
                return
            }

            state = .loaded(
                SharedItemDetailContent(item: item, history: history, ownerProfile: profile)
            )
        } catch {
            logger.error("Shared item detail load failed", error: error, category: "sharing")
            state = .failed(UserFacingError.from(error))
        }
    }

    /// Returns true when the update landed, so the caller can dismiss.
    func updateLocation(to description: String) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= StoredItem.locationMaxLength else {
            actionError = UserFacingError(
                title: "Location is too long",
                message: "Keep it under \(StoredItem.locationMaxLength) characters."
            )
            return false
        }

        do {
            try await roomSharingService.updateSharedItemLocation(
                itemID: itemID,
                description: trimmed
            )
            // Re-read rather than patching state locally: the server sets
            // `last_seen_at` and writes the history entry, so a local guess
            // would drift from what everyone else sees.
            await reload()
            return true
        } catch {
            logger.error("Updating shared item location failed", error: error, category: "sharing")
            actionError = UserFacingError.from(error)
            return false
        }
    }

    /// On-demand Storage download against the *owner's* folder --
    /// `AsyncStoredImage`'s local cache can never hold another account's
    /// images.
    func loadImageData(path: String) async throws -> Data {
        try await roomSharingService.loadSharedImageData(path: path, ownerID: ownerID)
    }
}
