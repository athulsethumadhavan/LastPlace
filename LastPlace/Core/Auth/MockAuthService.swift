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

    func signUp(email: String, password: String) async throws -> AuthUser {
        let newUser = AuthUser(id: UUID(), email: email)
        user = newUser
        continuation?.yield(newUser)
        return newUser
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let signedInUser = AuthUser(id: UUID(), email: email)
        user = signedInUser
        continuation?.yield(signedInUser)
        return signedInUser
    }

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
