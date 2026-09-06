//
//  SnapshotRepository.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol SnapshotRepository: Sendable {
    func fetchSnapshots(itemID: UUID) async throws -> [ItemSnapshot]
    func create(_ snapshot: ItemSnapshot) async throws -> ItemSnapshot
    func delete(snapshotID: UUID) async throws
    /// Bulk delete used when an item or room is removed.
    func deleteSnapshots(forItemID itemID: UUID) async throws
}
