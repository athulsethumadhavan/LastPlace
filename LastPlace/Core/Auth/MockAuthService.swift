//
//  MockAuthService.swift
//  LastPlace
//
//  Deterministic stand-in for previews/tests. Holds an in-memory user and a
//  manually-fed AsyncStream so preview screens
//  can exercise both the signed-out and signed-in states without a network
//  call.
//

import Foundation

final class MockAuthService: AuthService, @unchecked Sendable {
    var user: AuthUser?
    /// When true, `signUp` returns `.verificationRequired` instead of
    /// signing straight in -- lets `OTPView`'s preview (and manual testing
    /// of the whole signup -> OTP -> signed-in path) exercise the real flow
    /// without a network call. Any 6-digit code passed to `verifyOTP`
    /// succeeds.
    var simulateEmailVerification: Bool = false
    private var pendingVerificationEmail: String?
    private var continuation: AsyncStream<AuthUser?>.Continuation?

    init(user: AuthUser? = nil) {
        self.user = user
    }

    var currentUser: AuthUser? {
        get async { user }
    }

    var userChanges: AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            continuation.yield(user)
            self.continuation = continuation
        }
    }

    func signUp(email: String, password: String, fullName: String) async throws -> SignUpResult {
        if simulateEmailVerification {
            pendingVerificationEmail = email
            return .verificationRequired(email: email)
        }
        let newUser = AuthUser(id: UUID(), email: email, fullName: fullName)
        user = newUser
        continuation?.yield(newUser)
        return .signedIn(newUser)
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        if simulateEmailVerification, pendingVerificationEmail == email {
            throw AuthError.emailNotConfirmed(email: email)
        }
        let signedInUser = AuthUser(id: UUID(), email: email)
        user = signedInUser
        continuation?.yield(signedInUser)
        return signedInUser
    }

    func verifyOTP(email: String, token: String) async throws -> AuthUser {
        pendingVerificationEmail = nil
        let verifiedUser = AuthUser(id: UUID(), email: email)
        user = verifiedUser
        continuation?.yield(verifiedUser)
        return verifiedUser
    }

    func resendVerificationCode(email: String) async throws {}

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser {
        let signedInUser = AuthUser(id: UUID(), email: nil)
        user = signedInUser
        continuation?.yield(signedInUser)
        return signedInUser
    }

    @MainActor
    func signInWithGoogle() async throws -> AuthUser {
        let signedInUser = AuthUser(id: UUID(), email: "preview@gmail.com")
        user = signedInUser
        continuation?.yield(signedInUser)
        return signedInUser
    }

    func signOut() async throws {
        user = nil
        continuation?.yield(nil)
    }

    func requestPasswordReset(email: String) async throws {}

    func deleteAccount() async throws {
        user = nil
        continuation?.yield(nil)
    }
}
