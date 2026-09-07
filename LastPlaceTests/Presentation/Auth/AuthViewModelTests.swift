//
//  AuthViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class AuthViewModelTests: XCTestCase {
    private var authService: MockAuthService!
    private var analytics: MockAnalyticsService!
    private var authenticatedUsers: [AuthUser]!
    private var viewModel: AuthViewModel!

    override func setUp() async throws {
        try await super.setUp()
        authService = MockAuthService()
        analytics = MockAnalyticsService()
        authenticatedUsers = []
        viewModel = AuthViewModel(
            authService: authService,
            analytics: analytics,
            onAuthenticated: { [weak self] user in self?.authenticatedUsers.append(user) }
        )
    }

    func test_canSubmit_signIn_ignoresFullNameAndConfirmPassword() {
        viewModel.mode = .signIn
        viewModel.email = "person@example.com"
        viewModel.password = "password1"
        XCTAssertTrue(viewModel.canSubmit)
    }

    func test_canSubmit_signIn_requiresPasswordOfAtLeastSixCharacters() {
        viewModel.mode = .signIn
        viewModel.email = "person@example.com"
        viewModel.password = "12345"
        XCTAssertFalse(viewModel.canSubmit)
    }

    func test_canSubmit_signUp_requiresFullNameAndMatchingConfirmation() {
        viewModel.mode = .signUp
        viewModel.email = "person@example.com"
        viewModel.password = "password1"
        viewModel.confirmPassword = "password1"
        viewModel.fullName = ""
        XCTAssertFalse(viewModel.canSubmit)

        viewModel.fullName = "Jane Doe"
        viewModel.confirmPassword = "different"
        XCTAssertFalse(viewModel.canSubmit)

        viewModel.confirmPassword = "password1"
        XCTAssertTrue(viewModel.canSubmit)
    }

    func test_passwordMismatch_onlyFlaggedDuringSignUpOnceConfirmationTyped() {
        viewModel.mode = .signUp
        viewModel.password = "password1"
        XCTAssertFalse(viewModel.passwordMismatch, "Nothing typed into confirmPassword yet")

        viewModel.confirmPassword = "different"
        XCTAssertTrue(viewModel.passwordMismatch)

        viewModel.confirmPassword = "password1"
        XCTAssertFalse(viewModel.passwordMismatch)
    }

    func test_toggleMode_flipsModeAndClearsError() {
        viewModel.errorMessage = "Something went wrong"
        viewModel.toggleMode()
        XCTAssertEqual(viewModel.mode, .signUp)
        XCTAssertNil(viewModel.errorMessage)
        viewModel.toggleMode()
        XCTAssertEqual(viewModel.mode, .signIn)
    }

    func test_submit_signIn_succeeds_authenticatesAndLogsAnalytics() async {
        viewModel.mode = .signIn
        viewModel.email = "person@example.com"
        viewModel.password = "password1"

        viewModel.submit()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(authenticatedUsers.count, 1)
        XCTAssertEqual(analytics.loggedEventNames(), ["signed_in"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_submit_signUp_withVerificationRequired_setsPendingVerificationEmail() async {
        authService.simulateEmailVerification = true
        viewModel.mode = .signUp
        viewModel.email = "new@example.com"
        viewModel.password = "password1"
        viewModel.confirmPassword = "password1"
        viewModel.fullName = "New Person"

        viewModel.submit()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(viewModel.pendingVerificationEmail, "new@example.com")
        XCTAssertTrue(authenticatedUsers.isEmpty)
    }

    func test_submit_signIn_onUnverifiedAccount_routesToOTPScreen() async {
        authService.simulateEmailVerification = true
        // Puts the mock's internal "awaiting verification" state in place,
        // the same way a prior signUp() attempt would have.
        _ = try? await authService.signUp(email: "unverified@example.com", password: "password1", fullName: "Someone")

        viewModel.mode = .signIn
        viewModel.email = "unverified@example.com"
        viewModel.password = "password1"

        viewModel.submit()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(viewModel.pendingVerificationEmail, "unverified@example.com")
        XCTAssertTrue(authenticatedUsers.isEmpty)
    }

    func test_completeVerification_clearsPendingEmailAndAuthenticates() {
        viewModel.submit() // no-op: canSubmit is false with empty fields, just establishing baseline
        let user = AuthUser(id: UUID(), email: "verified@example.com")

        viewModel.completeVerification(user)

        XCTAssertNil(viewModel.pendingVerificationEmail)
        XCTAssertEqual(authenticatedUsers, [user])
    }

    func test_signInWithGoogle_succeeds_authenticatesAndLogsAnalytics() async {
        viewModel.signInWithGoogle()
        await waitUntil { !self.viewModel.isLoading }

        XCTAssertEqual(authenticatedUsers.count, 1)
        XCTAssertEqual(analytics.loggedEventNames(), ["signed_in"])
    }
}
