//
//  MockPendingChangesSyncing.swift
//  LastPlace
//
//  No-op stand-in for previews and `makePreview()`. Records calls so a test
//  can assert that a view model synced before hitting a server-side RPC --
//  that ordering is the whole point of the dependency, and it's the kind of
//  thing that's easy to accidentally drop in a refactor.
//

import Foundation

final class MockPendingChangesSyncing: PendingChangesSyncing, @unchecked Sendable {
    private(set) var syncCallCount = 0
    var shouldFail = false

    func sync(userID: UUID, imageStorage: ImageStorageService) async throws {
        syncCallCount += 1
        if shouldFail {
            struct MockSyncError: Error {}
            throw MockSyncError()
        }
    }
}
