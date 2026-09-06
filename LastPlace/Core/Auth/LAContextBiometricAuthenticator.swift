//
//  LAContextBiometricAuthenticator.swift
//  LastPlace
//
//  Production `BiometricAuthenticator`. A fresh `LAContext` is used per call
//  since Apple docs recommend against reusing one across evaluations once a
//  policy has already been evaluated.
//

import Foundation
import LocalAuthentication

struct LAContextBiometricAuthenticator: BiometricAuthenticator {
    func availableBiometry() -> BiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default:       return .none
        }
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
