//
//  MockHomeSharingService.swift
//  LastPlace
//
//  Deterministic stand-in for previews/tests, mirroring `MockBiometricAuthenticator`.
//  `CKShare` itself can't be meaningfully faked (it needs a saved root record to
//  exist), so `shareOrRefresh` just throws — nothing in this codebase's previews
//  presents `UICloudSharingController`, only the surrounding list/detail UI.
//

import Foundation
import CloudKit

final class MockHomeSharingService: HomeSharingService, @unchecked Sendable {
    let container = CKContainer(identifier: "iCloud.com.atsIOSDev.LastPlace")
    var sharedSnapshots: [SharedHomeSnapshot] = []
    var isSharedByHomeID: [UUID: Bool] = [:]

    func shareOrRefresh(home: Home, rooms: [Room], items: [StoredItem]) async throws -> CKShare {
        throw HomeSharingError.shareCreationFailed(underlying: "Sharing isn't available in previews.")
    }

    func isShared(homeID: UUID) async throws -> Bool {
        isSharedByHomeID[homeID] ?? false
    }

    func stopSharing(homeID: UUID) async throws {
        isSharedByHomeID[homeID] = false
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {}

    func fetchSharedSnapshots() async throws -> [SharedHomeSnapshot] {
        sharedSnapshots
    }
}
