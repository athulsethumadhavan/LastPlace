//
//  CloudKitHomeSharingService.swift
//  LastPlace
//
//  Concrete `HomeSharingService`. One custom `CKRecordZone` per home
//  (named "home-<uuid>"), one denormalized "HomeSnapshot" record in that
//  zone holding a JSON blob of the home's rooms/items, one `CKShare`
//  wrapping that record. Deleting the zone deletes the record and the
//  share together, which is how `stopSharing` revokes access in one call.
//
//  The zone-name convention lets the participant side recover a home's ID
//  straight from the zone it was invited into (`home-<uuid>` -> `<uuid>`),
//  so fetching the shared snapshot is a direct record lookup by ID rather
//  than a `CKQuery` — that sidesteps CloudKit's queryable-index/schema
//  promotion gotchas entirely, which matters here since there's no
//  compiler or CloudKit Dashboard access in this session to verify a query
//  would actually work end to end.
//

import Foundation
import CloudKit

/// Wire format for the JSON blob stored in each home's snapshot record.
/// Kept separate from the domain `Home`/`Room`/`StoredItem` types so a
/// future change to those doesn't silently change what's already been
/// published to CloudKit.
private struct HomeSharePayload: Codable {
    var homeID: UUID
    var homeName: String
    var updatedAt: Date
    var rooms: [RoomPayload]

    struct RoomPayload: Codable {
        var id: UUID
        var name: String
        var items: [ItemPayload]
    }

    struct ItemPayload: Codable {
        var id: UUID
        var name: String
        var locationDescription: String
        var isImportant: Bool
        var lastSeenAt: Date
    }
}

final class CloudKitHomeSharingService: HomeSharingService, @unchecked Sendable {
    private static let recordType = "HomeSnapshot"
    private static let payloadKey = "payloadJSON"
    private static let homeNameKey = "homeName"
    private static let zonePrefix = "home-"

    let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    init(containerIdentifier: String = "iCloud.com.atsIOSDev.LastPlace") {
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
    }

    // MARK: - Owner side

    func shareOrRefresh(home: Home, rooms: [Room], items: [StoredItem]) async throws -> CKShare {
        let zoneID = Self.zoneID(for: home.id)
        try await ensureZoneExists(zoneID)

        let recordID = CKRecord.ID(recordName: home.id.uuidString, zoneID: zoneID)
        let payload = Self.makePayload(home: home, rooms: rooms, items: items)
        let payloadData = try JSONEncoder.homeShare.encode(payload)
        let payloadString = String(decoding: payloadData, as: UTF8.self)

        if let existing = try await fetchRecord(recordID, in: privateDatabase) {
            existing[Self.payloadKey] = payloadString
            existing[Self.homeNameKey] = home.name

            if let share = try await existingShareRecord(for: existing) {
                configure(share)
                let saved = try await save([existing, share], to: privateDatabase)
                guard let savedShare = saved.first(where: { $0 is CKShare }) as? CKShare else {
                    throw HomeSharingError.shareCreationFailed(underlying: "CloudKit didn't return the share record after saving.")
                }
                return savedShare
            }

            // Record exists but was never shared. Shouldn't normally happen
            // (record + share are always created together below), but
            // handled rather than assumed away since `stopSharing` deletes
            // the whole zone and a retried/interrupted call could in
            // theory race it.
            let share = CKShare(rootRecord: existing)
            configure(share)
            return try await saveRecordAndShare(existing, share)
        }

        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[Self.payloadKey] = payloadString
        record[Self.homeNameKey] = home.name

        let share = CKShare(rootRecord: record)
        configure(share)
        return try await saveRecordAndShare(record, share)
    }

    func isShared(homeID: UUID) async throws -> Bool {
        let recordID = CKRecord.ID(recordName: homeID.uuidString, zoneID: Self.zoneID(for: homeID))
        guard let record = try await fetchRecord(recordID, in: privateDatabase) else { return false }
        return record.share != nil
    }

    func stopSharing(homeID: UUID) async throws {
        do {
            try await privateDatabase.deleteRecordZone(withID: Self.zoneID(for: homeID))
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // Already gone — nothing to stop.
        } catch {
            throw HomeSharingError.shareCreationFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Participant side

    func acceptShare(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: HomeSharingError.acceptFailed(underlying: error.localizedDescription))
                }
            }
            operation.qualityOfService = .userInitiated
            container.add(operation)
        }
    }

    func fetchSharedSnapshots() async throws -> [SharedHomeSnapshot] {
        let logger = OSAppLogger()
        do {
            let zones = try await sharedDatabase.allRecordZones()
            logger.log("fetchSharedSnapshots found \(zones.count) shared zone(s): \(zones.map(\.zoneID.zoneName))", category: "family-find")
            var snapshots: [SharedHomeSnapshot] = []
            for zone in zones {
                if let snapshot = try await fetchSnapshot(in: zone) {
                    snapshots.append(snapshot)
                } else {
                    logger.log("No snapshot resolved for zone \(zone.zoneID.zoneName)", category: "family-find")
                }
            }
            return snapshots.sorted { $0.homeName.localizedCaseInsensitiveCompare($1.homeName) == .orderedAscending }
        } catch let error as HomeSharingError {
            logger.error("fetchSharedSnapshots failed", error: error, category: "family-find")
            throw error
        } catch {
            logger.error("fetchSharedSnapshots failed", error: error, category: "family-find")
            throw HomeSharingError.fetchFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    private func fetchSnapshot(in zone: CKRecordZone) async throws -> SharedHomeSnapshot? {
        guard let homeIDString = Self.homeIDString(fromZoneName: zone.zoneID.zoneName),
              let homeID = UUID(uuidString: homeIDString) else { return nil }

        let recordID = CKRecord.ID(recordName: homeID.uuidString, zoneID: zone.zoneID)
        guard let record = try await fetchRecord(recordID, in: sharedDatabase) else {
            OSAppLogger().log("No record found at \(recordID) in shared database", category: "family-find")
            return nil
        }
        guard let jsonString = record[Self.payloadKey] as? String,
              let data = jsonString.data(using: .utf8) else {
            OSAppLogger().log("Record \(recordID) found but payload field was missing/unreadable", category: "family-find")
            return nil
        }

        let payload = try JSONDecoder.homeShare.decode(HomeSharePayload.self, from: data)
        let ownerName = (try? await ownerDisplayName(for: record)) ?? nil

        return SharedHomeSnapshot(
            homeID: payload.homeID,
            homeName: payload.homeName,
            ownerDisplayName: ownerName ?? "A family member",
            updatedAt: payload.updatedAt,
            rooms: payload.rooms.map { room in
                SharedRoomSnapshot(
                    id: room.id,
                    name: room.name,
                    items: room.items.map { item in
                        SharedItemSnapshot(
                            id: item.id,
                            name: item.name,
                            locationDescription: item.locationDescription,
                            isImportant: item.isImportant,
                            lastSeenAt: item.lastSeenAt
                        )
                    }
                )
            }
        )
    }

    private func ownerDisplayName(for record: CKRecord) async throws -> String? {
        guard let shareReference = record.share,
              let share = try await sharedDatabase.record(for: shareReference.recordID) as? CKShare,
              let nameComponents = share.owner.userIdentity.nameComponents else { return nil }
        let formatted = PersonNameComponentsFormatter().string(from: nameComponents)
        return formatted.isEmpty ? nil : formatted
    }

    private func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws {
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            _ = try await privateDatabase.save(CKRecordZone(zoneID: zoneID))
        }
    }

    private func fetchRecord(_ id: CKRecord.ID, in database: CKDatabase) async throws -> CKRecord? {
        do {
            return try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    private func existingShareRecord(for record: CKRecord) async throws -> CKShare? {
        guard let reference = record.share else { return nil }
        return try await privateDatabase.record(for: reference.recordID) as? CKShare
    }

    private func saveRecordAndShare(_ record: CKRecord, _ share: CKShare) async throws -> CKShare {
        let saved = try await save([record, share], to: privateDatabase)
        guard let savedShare = saved.first(where: { $0 is CKShare }) as? CKShare else {
            throw HomeSharingError.shareCreationFailed(underlying: "CloudKit didn't return the share record after saving.")
        }
        return savedShare
    }

    private func save(_ records: [CKRecord], to database: CKDatabase) async throws -> [CKRecord] {
        do {
            let result = try await database.modifyRecords(saving: records, deleting: [])
            return try result.saveResults.values.map { try $0.get() }
        } catch {
            throw HomeSharingError.shareCreationFailed(underlying: error.localizedDescription)
        }
    }

    /// Read-only always — `Family Find` is a shared snapshot, not
    /// collaborative editing (see this type's file-level doc comment), so
    /// `UICloudSharingController` (configured in `CloudSharingViewRepresentable`)
    /// never offers a write option regardless of this setting.
    ///
    /// `publicPermission = .none` (invite-only) is required, not just
    /// preferred: public/anyone-with-the-link shares are meant to stay
    /// viewable even by people without the app, so iOS routes them to
    /// icloud.com's web viewer instead of handing off to `LastPlace` —
    /// confirmed by testing (`.readOnly` made the native "Open in
    /// LastPlace?" prompt stop appearing entirely, replaced by a plain
    /// Safari sign-in page). Only invite-only shares trigger the native
    /// accept flow. The tradeoff: "Copy Link" alone doesn't register
    /// anyone as a participant, so testing/inviting has to go through
    /// `UICloudSharingController`'s own Mail/Messages option addressed to
    /// a specific person, not a link copied and sent through some other
    /// channel.
    private func configure(_ share: CKShare) {
        share.publicPermission = .none
    }

    private static func zoneID(for homeID: UUID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "\(zonePrefix)\(homeID.uuidString)", ownerName: CKCurrentUserDefaultName)
    }

    private static func homeIDString(fromZoneName zoneName: String) -> String? {
        guard zoneName.hasPrefix(zonePrefix) else { return nil }
        return String(zoneName.dropFirst(zonePrefix.count))
    }

    private static func makePayload(home: Home, rooms: [Room], items: [StoredItem]) -> HomeSharePayload {
        let itemsByRoom = Dictionary(grouping: items, by: \.roomID)
        return HomeSharePayload(
            homeID: home.id,
            homeName: home.name,
            updatedAt: Date(),
            rooms: rooms.map { room in
                HomeSharePayload.RoomPayload(
                    id: room.id,
                    name: room.name,
                    items: (itemsByRoom[room.id] ?? []).map { item in
                        HomeSharePayload.ItemPayload(
                            id: item.id,
                            name: item.name,
                            locationDescription: item.locationDescription,
                            isImportant: item.isImportant,
                            lastSeenAt: item.lastSeenAt
                        )
                    }
                )
            }
        )
    }
}

private extension JSONEncoder {
    static let homeShare: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let homeShare: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
