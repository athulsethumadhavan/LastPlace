//
//  AuthService.swift
//  LastPlace
//
//  Protocol-wrapped Supabase Auth: view models and previews depend on this
//  protocol and plain Sendable types only, never on the Supabase package
//  directly, so a Mock implementation can stand in for previews/tests.
//

import Foundation

/// The signed-in account. Deliberately minimal for Phase 1 — display name
/// and avatar live in the `profiles` table and are read separately once a
/// profile-fetching use case exists.
struct AuthUser: Identifiable, Hashable, Sendable {
    let id: UUID
    let email: String?
}

enum AuthError: LocalizedError, Sendable {
    case signUpFailed(underlying: String)
    case signInFailed(underlying: String)
    case signOutFailed(underlying: String)
    case appleSignInFailed(underlying: String)
    case googleSignInFailed(underlying: String)
    case passwordResetFailed(underlying: String)
    case accountDeletionFailed(underlying: String)
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .signUpFailed(let underlying):
            "Couldn't create your account: \(underlying)"
        case .signInFailed(let underlying):
            "Couldn't sign in: \(underlying)"
        case .signOutFailed(let underlying):
            "Couldn't sign out: \(underlying)"
        case .appleSignInFailed(let underlying):
            "Sign in with Apple didn't complete: \(underlying)"
        case .googleSignInFailed(let underlying):
            "Sign in with Google didn't complete: \(underlying)"
        case .passwordResetFailed(let underlying):
            "Couldn't send the reset email: \(underlying)"
        case .accountDeletionFailed(let underlying):
            "Couldn't delete your account: \(underlying)"
        case .sessionUnavailable:
            "You're not signed in."
        }
    }
}

protocol AuthService: Sendable {
    /// The signed-in user, if any. Reads the current session synchronously
    /// where possible (the underlying client keeps this cached/refreshed).
    var currentUser: AuthUser? { get async }

    /// Emits the current user (or nil) once immediately, then again on every
    /// auth state change: sign in, sign out, token refresh, or a session
    /// restored from the keychain on launch. Root-level view models observe
    /// this to decide whether to show the signed-out or signed-in flow.
    var userChanges: AsyncStream<AuthUser?> { get }

    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser

    /// `idToken`/`nonce` come from an `ASAuthorizationAppleIDCredential`
    /// (see `SignInWithAppleButton` in the Sign In screen).
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser

    /// Presents Google's consent screen via the GoogleSignIn-iOS SDK, which
    /// needs a UIKit presentation anchor -- MainActor so the implementation
    /// can safely grab the current key window's top view controller.
    @MainActor
    func signInWithGoogle() async throws -> AuthUser

    func signOut() async throws

    /// Sends a password-reset email via Supabase Auth. The link in that
    /// email opens `SupabaseConfig.projectURL`'s hosted reset page by
    /// default; wiring a custom in-app deep link for this is deferred until
    /// the app has a real launch-time auth gate (Phase 2+).
    func requestPasswordReset(email: String) async throws

    /// Permanently deletes the account via the `delete-account` Edge
    /// Function (deployed, service-role-key-backed) -- a signed-in client
    /// can never be trusted to delete its own `auth.users` row directly.
    func deleteAccount() async throws
}
