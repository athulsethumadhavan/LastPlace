//
//  SecurityViewModelTests.swift
//  LastPlaceTests
//

import XCTest
@testable import LastPlace

@MainActor
final class SecurityViewModelTests: XCTestCase {
    private func makeStore() -> AppLockSettingsStore {
        // A dedicated suite per test avoids leaking `isEnabled` state into
        // `UserDefaults.standard` between test runs.
        let suiteName = "SecurityViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppLockSettingsStore(defaults: defaults)
    }

    func test_biometryKind_reflectsAuthenticatorCapability() {
        let viewModel = SecurityViewModel(
            store: makeStore(),
            biometricAuthenticator: MockBiometricAuthenticator(biometry: .faceID)
        )
        XCTAssertEqual(viewModel.biometryKind, .faceID)
    }

    func test_isEnabled_readsAndWritesThroughToStore() {
        let store = makeStore()
        let viewModel = SecurityViewModel(
            store: store,
            biometricAuthenticator: MockBiometricAuthenticator(biometry: .none)
        )

        XCTAssertFalse(viewModel.isEnabled)
        viewModel.isEnabled = true
        XCTAssertTrue(store.isEnabled)
        XCTAssertTrue(viewModel.isEnabled)
    }
}
