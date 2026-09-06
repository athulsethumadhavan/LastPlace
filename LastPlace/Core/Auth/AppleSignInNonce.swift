//
//  AppleSignInNonce.swift
//  LastPlace
//
//  Sign in with Apple + Supabase requires a raw nonce sent to Supabase and
//  its SHA256 hash sent to Apple's authorization request, so a replayed
//  Apple ID token can't be reused against a different nonce. This is
//  Apple's standard sample pattern, adapted from their "Implementing User
//  Authentication with Sign in with Apple" documentation.
//

import CryptoKit
import Foundation

enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Unable to generate secure random bytes for the Apple sign-in nonce.")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
