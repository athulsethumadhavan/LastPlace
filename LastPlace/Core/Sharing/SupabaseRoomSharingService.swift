//
//  SupabaseRoomSharingService.swift
//  LastPlace
//
//  Concrete RoomSharingService backed by Supabase — the `room_shares`,
//  `rooms`, `items`, and `profiles` tables from the `add_room_sharing` and
//  `add_room_sharing_storage_access` migrations. RLS on those tables is what
//  actually enforces who can see/change what; this file just shapes the
//  requests and maps rows into Domain types.
//
//  Wire-format row types below are private to this file and deliberately
//  NOT added to `Core/Sync/SupabaseRows.swift` — that file's own doc comment
//  scopes its types to `SyncEngine`'s owner-only local-cache traffic, and
//  Sharing's cross-account reads don't belong there.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session. The `.rpc(_:params:)`, Realtime `postgresChange`/`subscribe()`,
//  and `.from(...).update(...)` call shapes were checked against Supabase's
//  official Swift docs for supabase-swift 2.52.0 (the version pinned in
//  this project's Package.resolved) before writing this file, but Xcode's
//  own compiler is the final word — build this file first after pulling.
//

import Foundation
import Supabase

final class SupabaseRoomSharingService: RoomSharingService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func inviteToRoom(roomID: UUID, inviteeEmail: String) async throws -> RoomShare {
        do {
            let row: RoomShareRow = try await client
                .rpc("invite_to_room", params: [
                    "p_room_id": roomID.uuidString,
                    "p_invitee_email": inviteeEmail
                ])
                .execute()
                .value
            return RoomShare(row)
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("no account found") {
                throw RoomSharingError.noAccountFound
            }
            if message.localizedCaseInsensitiveContains("not owned by caller")
                || message.localizedCaseInsensitiveContains("room not found") {
                throw RoomSharingError.notOwner
            }
            throw RoomSharingError.inviteFailed(underlying: message)
        }
    }

    func outgoingShares(roomID: UUID) async throws -> [RoomShare] {
        do {
            let rows: [RoomShareRow] = try await client
                .from("room_shares")
                .select()
                .eq("room_id", value: roomID.uuidString)
                .execute()
                .value
            return rows.map(RoomShare.init)
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func incomingShares() async throws -> [RoomShare] {
        guard let userID = await currentUserID() else {
            throw RoomSharingError.notAuthenticated
        }
        do {
            let rows: [RoomShareRow] = try await client
                .from("room_shares")
                .select()
                .eq("shared_with_user_id", value: userID.uuidString)
                .execute()
                .value
            return rows.map(RoomShare.init)
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func acceptShare(_ shareID: UUID) async throws {
        do {
            try await client
                .from("room_shares")
                .update(["accepted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: shareID.uuidString)
                .execute()
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func removeShare(_ shareID: UUID) async throws {
        do {
            try await client
                .from("room_shares")
                .delete()
                .eq("id", value: shareID.uuidString)
                .execute()
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
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

    func fetchSharedRoomDetail(roomID: UUID) async throws -> (room: Room, items: [StoredItem]) {
        do {
            async let roomRowTask: SharedRoomRow = client
                .from("rooms")
                .select()
                .eq("id", value: roomID.uuidString)
                .single()
                .execute()
                .value
            async let itemRowsTask: [SharedItemRow] = client
                .from("items")
                .select()
                .eq("room_id", value: roomID.uuidString)
                .execute()
                .value
            let (roomRow, itemRows) = try await (roomRowTask, itemRowsTask)
            return (Room(roomRow), itemRows.map(StoredItem.init))
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func sharedItemHistory(itemID: UUID) async throws -> [SharedItemHistoryEntry] {
        do {
            let rows: [SharedSnapshotRow] = try await client
                .from("item_snapshots")
                .select()
                .eq("item_id", value: itemID.uuidString)
                .order("captured_at", ascending: false)
                .execute()
                .value

            // One profile fetch per distinct author, not per row -- an item
            // moved twenty times by two people is two lookups, not twenty.
            let authorIDs = Set(rows.compactMap(\.createdBy))
            var profiles: [UUID: SharingProfile] = [:]
            for id in authorIDs {
                if let profile = try? await fetchProfile(userID: id) {
                    profiles[id] = profile
                }
            }

            return rows.map { row in
                SharedItemHistoryEntry(
                    id: row.id,
                    locationDescription: row.locationDescription,
                    capturedAt: row.capturedAt,
                    setBy: row.createdBy.flatMap { profiles[$0] }
                )
            }
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func updateSharedItemLocation(itemID: UUID, description: String) async throws {
        do {
            try await client
                .rpc("update_shared_item_location", params: [
                    "p_item_id": itemID.uuidString,
                    "p_description": description
                ])
                .execute()
        } catch {
            let message = error.localizedDescription
            // The function raises this when the share was revoked between
            // the screen loading and the save landing -- worth naming, since
            // "you no longer have access" is actionable and the raw Postgres
            // text is not.
            if message.localizedCaseInsensitiveContains("not shared with you") {
                throw RoomSharingError.notShared
            }
            throw RoomSharingError.updateFailed(underlying: message)
        }
    }

    func loadSharedImageData(path: String, ownerID: UUID) async throws -> Data {
        do {
            return try await client.storage.from("item-images")
                .download(path: ownerID.storageKey(for: path))
        } catch {
            throw RoomSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    func observeIncomingShares() -> AsyncStream<[RoomShare]> {
        AsyncStream { continuation in
            let task = Task {
                guard let userID = await currentUserID() else {
                    continuation.finish()
                    return
                }
                if let initial = try? await incomingShares() {
                    continuation.yield(initial)
                }
                let channel = await client.channel("room_shares_for_\(userID.uuidString)")
                let changes = await channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "room_shares",
                    filter: .eq("shared_with_user_id", value: userID.uuidString)
                )
                await channel.subscribe()
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    if let refreshed = try? await incomingShares() {
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

private struct RoomShareRow: Codable, Sendable {
    let id: UUID
    let roomID: UUID
    let ownerID: UUID
    let sharedWithUserID: UUID
    let invitedAt: Date
    let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case ownerID = "owner_id"
        case sharedWithUserID = "shared_with_user_id"
        case invitedAt = "invited_at"
        case acceptedAt = "accepted_at"
    }
}

private struct SharedRoomRow: Codable, Sendable {
    let id: UUID
    let homeID: UUID
    let name: String
    let iconName: String
    let coverImagePath: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case homeID = "home_id"
        case name
        case iconName = "icon_name"
        case coverImagePath = "cover_image_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct SharedItemRow: Codable, Sendable {
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
    }
}

private struct SharedSnapshotRow: Codable, Sendable {
    let id: UUID
    let locationDescription: String
    let capturedAt: Date
    /// Null for history recorded before the `created_by` column existed.
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case locationDescription = "location_description"
        case capturedAt = "captured_at"
        case createdBy = "created_by"
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

private extension RoomShare {
    init(_ row: RoomShareRow) {
        self.init(
            id: row.id,
            roomID: row.roomID,
            ownerID: row.ownerID,
            sharedWithUserID: row.sharedWithUserID,
            invitedAt: row.invitedAt,
            acceptedAt: row.acceptedAt
        )
    }
}

private extension SharingProfile {
    init(_ row: ProfileRow) {
        self.init(id: row.id, email: row.email, displayName: row.displayName)
    }
}

private extension Room {
    init(_ row: SharedRoomRow) {
        self.init(
            id: row.id,
            homeID: row.homeID,
            name: row.name,
            iconName: row.iconName,
            coverImagePath: row.coverImagePath,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}

private extension StoredItem {
    init(_ row: SharedItemRow) {
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
            isImportant: row.isImportant
        )
    }
}
