//
//  AccountViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class AccountViewModelTests: XCTestCase {
    private var authService: MockAuthService!
    private var deviceTokenService: MockDeviceTokenService!
    private var signedOutCallCount: Int!
    private var viewModel: AccountViewModel!
    private var seededUser: AuthUser!

    override func setUp() async throws {
        try await super.setUp()
        seededUser = AuthUser(id: UUID(), email: "person@example.com", fullName: "Jane Doe")
        authService = MockAuthService(user: seededUser)
        deviceTokenService = MockDeviceTokenService()
        signedOutCallCount = 0
        viewModel = AccountViewModel(
            authService: authService,
            deviceTokenService: deviceTokenService,
            onSignedOut: { [weak self] in self?.signedOutCallCount += 1 }
        )
    }

    func test_init_observesCurrentlySignedInUser() async {
        await waitUntil { self.viewModel.user != nil }
        XCTAssertEqual(viewModel.user, seededUser)
    }

    func test_signOut_clearsSessionAndNotifiesCaller() async {
        await waitUntil { self.viewModel.user != nil }

        viewModel.signOut()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(signedOutCallCount, 1)
        XCTAssertNil(viewModel.errorMessage)
        let currentUser = await authService.currentUser
        XCTAssertNil(currentUser)
    }

    func test_deleteAccount_removesAccountAndNotifiesCaller() async {
        await waitUntil { self.viewModel.user != nil }

        viewModel.deleteAccount()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(signedOutCallCount, 1)
        XCTAssertNil(viewModel.errorMessage)
    }
}
