//
//  OTPViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class OTPViewModelTests: XCTestCase {
    private var authService: MockAuthService!
    private var verifiedUsers: [AuthUser]!
    private var viewModel: OTPViewModel!

    override func setUp() async throws {
        try await super.setUp()
        authService = MockAuthService()
        verifiedUsers = []
        viewModel = OTPViewModel(
            email: "person@example.com",
            authService: authService,
            onVerified: { [weak self] user in self?.verifiedUsers.append(user) }
        )
    }

    func test_code_filtersNonDigitsAndCapsAtSixCharacters() {
        viewModel.code = "12a3-4b5!6789"
        XCTAssertEqual(viewModel.code, "123456")
    }

    func test_canSubmit_requiresExactlySixDigits() {
        viewModel.code = "12345"
        XCTAssertFalse(viewModel.canSubmit)
        viewModel.code = "123456"
        XCTAssertTrue(viewModel.canSubmit)
    }

    func test_startsWithThirtySecondCooldown() {
        XCTAssertEqual(viewModel.resendCooldown, 30)
    }

    func test_submit_withValidCode_verifiesAndClearsError() async {
        viewModel.code = "123456"

        viewModel.submit()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(verifiedUsers.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_submit_belowSixDigits_doesNothing() async {
        viewModel.code = "123"

        viewModel.submit()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertTrue(verifiedUsers.isEmpty)
    }
}
