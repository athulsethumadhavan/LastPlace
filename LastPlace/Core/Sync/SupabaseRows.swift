//
//  SupabaseRows.swift
//  LastPlace
//
//  Codable wire types matching the Postgres tables from the
//  `create_inventory_tables` migration, one per table. Explicit
//  `CodingKeys` throughout rather than relying on a decoder's
//  snake_case-conversion strategy — safer to verify by eye against the
//  actual SQL column names than to trust an implicit conversion rule with
//  no compiler here to catch a mismatch.
//
//  Sync-only types: these never cross into the Domain layer. `SyncEngine`
//  converts directly between these and SwiftData entities.
//

import Foundation

struct HomeRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RoomRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let homeID: UUID
    let name: String
    let iconName: String
    let coverImagePath: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case homeID = "home_id"
        case name
        case iconName = "icon_name"
        case coverImagePath = "cover_image_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ItemRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
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
        case userID = "user_id"
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

struct ItemSnapshotRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let itemID: UUID
    let roomID: UUID
    let imagePath: String?
    let locationDescription: String
    let capturedAt: Date
    let confidence: Double
    let source: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case itemID = "item_id"
        case roomID = "room_id"
        case imagePath = "image_path"
        case locationDescription = "location_description"
        case capturedAt = "captured_at"
        case confidence
        case source
    }
}

// Named `ChecklistTableRow`/`ChecklistEntryTableRow` rather than the more
// obvious `ChecklistRow`/`ChecklistEntryRow` -- those names are already
// taken by the SwiftUI row views in Presentation/Checklists/.
struct ChecklistTableRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let typeKind: String
    let customLabel: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case typeKind = "type_kind"
        case customLabel = "custom_label"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChecklistEntryTableRow: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let checklistID: UUID
    let title: String
    let linkedItemID: UUID?
    let locationDescription: String?
    let isCompleted: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case checklistID = "checklist_id"
        case title
        case linkedItemID = "linked_item_id"
        case locationDescription = "location_description"
        case isCompleted = "is_completed"
        case sortOrder = "sort_order"
    }
}
