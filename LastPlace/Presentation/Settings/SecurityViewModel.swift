//
//  SecurityViewModel.swift
//  LastPlace
//
//  Same thin pass-through shape as `AppearanceViewModel` — `isEnabled` reads
//  and writes straight through to `AppLockSettingsStore`'s own `@Observable`
//  storage. `biometryKind` is read once at construction: what the device
//  supports doesn't change mid-session.
//

import Foundation
import Observation

@Observable
@MainActor
final class SecurityViewModel {
    let biometryKind: BiometryKind

    private let store: AppLockSettingsStore

    init(store: AppLockSettingsStore, biometricAuthenticator: BiometricAuthenticator) {
        self.store = store
        self.biometryKind = biometricAuthenticator.availableBiometry()
    }

    var isEnabled: Bool {
        get { store.isEnabled }
        set { store.isEnabled = newValue }
    }
}
