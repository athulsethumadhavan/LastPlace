//
//  SupabaseItemGiftingService.swift
//  LastPlace
//
//  Concrete ItemGiftingService backed by Supabase — the `item_gifts` table
//  and the `gift_item`/`accept_gift` Postgres functions from the
//  `add_item_gifting` migration. Wire-format row types below are private
//  to this file, same rationale as `Core/Sharing/SupabaseRoomSharingService.swift`:
//  kept separate from `Core/Sync/SupabaseRows.swift`'s Sync-only types.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session, same caveat as `SupabaseRoomSharingService`. The `.rpc`,
//  Realtime, and `.from().update()/.delete()` shapes were verified against
//  Supabase's official Swift docs for supabase-swift 2.52.0 while building
//  Phase 4; this file reuses those same shapes. Build in Xcode first.
//

import Foundation
import Supabase

final class SupabaseItemGiftingService: ItemGiftingService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func giftItem(itemID: UUID, recipientEmail: String) async throws -> ItemGift {
        do {
            let row: ItemGiftRow = try await client
                .rpc("gift_item", params: [
                    "p_item_id": itemID.uuidString,
                    "p_recipient_email": recipientEmail
                ])
                .execute()
                .value
            return ItemGift(row)
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("no account found") {
                throw ItemGiftingError.noAccountFound
            }
            if message.localizedCaseInsensitiveContains("not owned by caller") {
                throw ItemGiftingError.notOwner
            }
            // "already has a pending gift" is the friendly message raised
            // explicitly by `gift_item`; "duplicate key" / "item_gifts_one_pending_per_item"
            // is what a rare concurrent-request race would surface instead,
            // caught directly at the unique index rather than the earlier check.
            if message.localizedCaseInsensitiveContains("already has a pending gift")
                || message.localizedCaseInsensitiveContains("item_gifts_one_pending_per_item") {
                throw ItemGiftingError.alreadyPendingGift
            }
            throw ItemGiftingError.sendFailed(underlying: message)
        }
    }

    func outgoingGifts() async throws -> [ItemGift] {
        guard let userID = await currentUserID() else { throw ItemGiftingError.notAuthenticated }
        do {
            let rows: [ItemGiftRow] = try await client
                .from("item_gifts")
                .select()
                .eq("from_user_id", value: userID.uuidString)
                .execute()
                .value
            return rows.map(ItemGift.init)
        } catch {
            throw ItemGiftingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func incomingGifts() async throws -> [ItemGift] {
        guard let userID = await currentUserID() else { throw ItemGiftingError.notAuthenticated }
        do {
            let rows: [ItemGiftRow] = try await client
                .from("item_gifts")
                .select()
                .eq("to_user_id", value: userID.uuidString)
                .execute()
                .value
            return rows.map(ItemGift.init)
        } catch {
            throw ItemGiftingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func cancelGift(_ giftID: UUID) async throws {
        do {
            try await client
                .from("item_gifts")
                .delete()
                .eq("id", value: giftID.uuidString)
                .execute()
        } catch {
            throw ItemGiftingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func declineGift(_ giftID: UUID) async throws {
        do {
            try await client
                .from("item_gifts")
                .update([
                    "status": "declined",
                    "resolved_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: giftID.uuidString)
                .execute()
        } catch {
            throw ItemGiftingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    /// Resolves the gift and creates the independent item *before* touching
    /// Storage at all, then treats the photo copy as a best-effort step on
    /// top of an item that already exists validly either way. This ordering
    /// matters: the old version uploaded the photo first and only then
    /// called `accept_gift`, so a failure in that RPC (a race with a
    /// concurrent accept/decline, a dropped connection, anything) left a
    /// fully-uploaded photo in the recipient's Storage folder with nothing
    /// in Postgres ever referencing it -- permanently orphaned, since
    /// nothing else would ever look for it. Doing the RPC first means the
    /// only failure mode left is "item exists, photo copy didn't happen",
    /// which is the same, already-handled state as any item saved without a
    /// photo -- not a bug.
    func acceptGift(_ giftID: UUID, intoRoomID roomID: UUID) async throws -> (item: StoredItem, imageData: Data?) {
        guard let recipientID = await currentUserID() else { throw ItemGiftingError.notAuthenticated }
        do {
            let gift: ItemGiftRow = try await client
                .from("item_gifts")
                .select()
                .eq("id", value: giftID.uuidString)
                .single()
                .execute()
                .value

            let noImagePath: String? = nil
            let itemRow: GiftedItemRow = try await client
                .rpc("accept_gift", params: [
                    "p_gift_id": giftID.uuidString,
                    "p_room_id": roomID.uuidString,
                    "p_new_image_path": noImagePath
                ])
                .execute()
                .value
            var item = StoredItem(itemRow)

            guard let sourcePath = gift.sourceImagePath else {
                return (item, nil)
            }

            // Storage holds bare filenames under a "{user_id}/" folder (see
            // SyncEngine.pushPendingImages/pullMissingImages) -- download
            // from the sender's folder, then re-upload under this
            // account's own folder so the gift becomes a fully independent
            // photo copy, not a cross-account reference that would break if
            // the sender later deletes the item. The gift itself is
            // already resolved at this point regardless of what happens
            // below, so none of this can fail the accept as a whole.
            guard let data = try? await client.storage.from("item-images")
                .download(path: "\(gift.fromUserID)/\(sourcePath)") else {
                return (item, nil)
            }
            let filename = "gift-\(UUID().uuidString).jpg"
            guard (try? await client.storage.from("item-images").upload(
                "\(recipientID)/\(filename)",
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )) != nil else {
                return (item, nil)
            }

            do {
                try await client.from("items")
                    .update(["image_path": filename])
                    .eq("id", value: item.id.uuidString)
                    .execute()
                item.imagePath = filename
                return (item, data)
            } catch {
                // The upload succeeded but attaching it to the item didn't
                // -- clean up the now-unreferenced Storage object rather
                // than leaving it behind. VERIFY-BEFORE-TRUST: `.remove(paths:)`
                // is the documented supabase-swift storage delete call but
                // hasn't been exercised anywhere else in this codebase yet;
                // confirm the signature in Xcode. Best-effort either way --
                // if this also fails, the item is still a perfectly valid,
                // photo-less item, not a lost gift.
                try? await client.storage.from("item-images")
                    .remove(paths: ["\(recipientID)/\(filename)"])
                return (item, nil)
            }
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("already been resolved") {
                throw ItemGiftingError.alreadyResolved
            }
            if message.localizedCaseInsensitiveContains("room not found") {
                throw ItemGiftingError.roomNotOwned
            }
            throw ItemGiftingError.acceptFailed(underlying: message)
        }
    }

    func fetchProfile(userID: UUID) async throws -> SharingProfile? {
        let row: ProfileRow? = try? await client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .single()
            .execute()
            .value
        return row.map(SharingProfile.init)
    }

    func observeIncomingGifts() -> AsyncStream<[ItemGift]> {
        AsyncStream { continuation in
            let task = Task {
                guard let userID = await currentUserID() else {
                    continuation.finish()
                    return
                }
                if let initial = try? await incomingGifts() {
                    continuation.yield(initial)
                }
                let channel = await client.channel("item_gifts_for_\(userID.uuidString)")
                let changes = await channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "item_gifts",
                    filter: .eq("to_user_id", value: userID.uuidString)
                )
                await channel.subscribe()
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    if let refreshed = try? await incomingGifts() {
                        continuation.yield(refreshed)
                    }
                }
                await client.removeChannel(channel)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func currentUserID() async -> UUID? {
        (try? await client.auth.session)?.user.id
    }
}

// MARK: - Wire rows (private — never exposed outside this file)

private struct ItemGiftRow: Codable, Sendable {
    let id: UUID
    let fromUserID: UUID
    let toUserID: UUID
    let status: String
    let itemName: String
    let itemCategory: String
    let itemNotes: String?
    let itemLocationDescription: String
    let sourceImagePath: String?
    let createdAt: Date
    let resolvedAt: Date?
    let resolvedItemID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserID = "from_user_id"
        case toUserID = "to_user_id"
        case status
        case itemName = "item_name"
        case itemCategory = "item_category"
        case itemNotes = "item_notes"
        case itemLocationDescription = "item_location_description"
        case sourceImagePath = "source_image_path"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
        case resolvedItemID = "resolved_item_id"
    }
}

private struct GiftedItemRow: Codable, Sendable {
    let id: UUID
    let roomID: UUID
    let name: String
    let category: String
    let notes: String?
    let imagePath: String?
    let locationDescription: String
    let lastSeenAt: Date
    let createdAt: Date
    let updatedAt: Date
    let isImportant: Bool
    let originSharedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case name
        case category
        case notes
        case imagePath = "image_path"
        case locationDescription = "location_description"
        case lastSeenAt = "last_seen_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isImportant = "is_important"
        case originSharedBy = "origin_shared_by"
    }
}

private struct ProfileRow: Codable, Sendable {
    let id: UUID
    let email: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
    }
}

// MARK: - Row → Domain mapping

private extension ItemGift {
    init(_ row: ItemGiftRow) {
        self.init(
            id: row.id,
            fromUserID: row.fromUserID,
            toUserID: row.toUserID,
            status: ItemGiftStatus(rawValue: row.status) ?? .pending,
            itemName: row.itemName,
            itemCategory: ItemCategory(rawValue: row.itemCategory) ?? .other,
            itemNotes: row.itemNotes,
            itemLocationDescription: row.itemLocationDescription,
            sourceImagePath: row.sourceImagePath,
            createdAt: row.createdAt,
            resolvedAt: row.resolvedAt,
            resolvedItemID: row.resolvedItemID
        )
    }
}

private extension SharingProfile {
    init(_ row: ProfileRow) {
        self.init(id: row.id, email: row.email, displayName: row.displayName)
    }
}

private extension StoredItem {
    init(_ row: GiftedItemRow) {
        self.init(
            id: row.id,
            roomID: row.roomID,
            name: row.name,
            category: ItemCategory(rawValue: row.category) ?? .other,
            notes: row.notes,
            imagePath: row.imagePath,
            locationDescription: row.locationDescription,
            lastSeenAt: row.lastSeenAt,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            isImportant: row.isImportant,
            originSharedBy: row.originSharedBy
        )
    }
}
