//
//  ShareRoomViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class ShareRoomViewModelTests: XCTestCase {
    private var roomSharingService: MockRoomSharingService!
    private var syncEngine: MockPendingChangesSyncing!
    private var authService: MockAuthService!
    private var viewModel: ShareRoomViewModel!
    private var roomID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        roomID = UUID()
        roomSharingService = MockRoomSharingService()
        syncEngine = MockPendingChangesSyncing()
        authService = MockAuthService(user: AuthUser(id: UUID(), email: "owner@example.com"))
        viewModel = ShareRoomViewModel(
            roomID: roomID,
            roomSharingService: roomSharingService,
            syncEngine: syncEngine,
            authService: authService,
            imageStorage: MockImageStorageService(),
            analytics: MockAnalyticsService(),
            logger: OSAppLogger()
        )
    }

    func test_canInvite_requiresPlausibleEmail() {
        XCTAssertFalse(viewModel.canInvite)
        viewModel.inviteEmail = "not-an-email"
        XCTAssertFalse(viewModel.canInvite)
        viewModel.inviteEmail = "friend@example.com"
        XCTAssertTrue(viewModel.canInvite)
    }

    func test_load_populatesOutgoingSharesWithProfiles() async throws {
        let recipientID = UUID()
        roomSharingService.profiles[recipientID] = SharingProfile(id: recipientID, email: "friend@example.com", displayName: "Friend")
        roomSharingService.outgoingByRoom[roomID] = [
            RoomShare(id: UUID(), roomID: roomID, ownerID: UUID(), sharedWithUserID: recipientID, invitedAt: Date(), acceptedAt: nil)
        ]

        await viewModel.load()

        let summaries = try XCTUnwrap(viewModel.state.value)
        XCTAssertEqual(summaries.map(\.profile?.displayLabel), ["Friend"])
    }

    func test_invite_syncsFirstThenInvitesAndLogsAnalytics() async throws {
        let recipientID = UUID()
        roomSharingService.profiles[recipientID] = SharingProfile(id: recipientID, email: "friend@example.com", displayName: nil)
        viewModel.inviteEmail = "friend@example.com"

        viewModel.invite()
        await waitUntil { !self.viewModel.isInviting }

        XCTAssertEqual(syncEngine.syncCallCount, 1)
        XCTAssertEqual(viewModel.state.value?.count, 1)
        XCTAssertEqual(viewModel.inviteEmail, "")
        XCTAssertNil(viewModel.inviteError)
    }

    func test_invite_withUnknownEmail_setsInviteError() async throws {
        viewModel.inviteEmail = "nobody@example.com"

        viewModel.invite()
        await waitUntil { !self.viewModel.isInviting }

        XCTAssertNotNil(viewModel.inviteError)
    }

    func test_revoke_removesShare() async throws {
        let shareID = UUID()
        roomSharingService.outgoingByRoom[roomID] = [
            RoomShare(id: shareID, roomID: roomID, ownerID: UUID(), sharedWithUserID: UUID(), invitedAt: Date(), acceptedAt: nil)
        ]
        await viewModel.load()

        viewModel.revoke(shareID)
        await waitUntil { self.viewModel.mutatingShareID == nil }

        XCTAssertEqual(viewModel.state.value?.count, 0)
    }
}
