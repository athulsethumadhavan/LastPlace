//
//  MockBiometricAuthenticator.swift
//  LastPlace
//
//  Deterministic authenticator for previews and unit tests — no system
//  prompt, just configurable canned answers.
//

import Foundation

struct MockBiometricAuthenticator: BiometricAuthenticator {
    var biometry: BiometryKind = .faceID
    var authenticationSucceeds: Bool = true

    func availableBiometry() -> BiometryKind { biometry }

    func authenticate(reason: String) async -> Bool { authenticationSucceeds }
}
