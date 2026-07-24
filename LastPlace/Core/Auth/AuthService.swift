//
//  AuthService.swift
//  LastPlace
//
//  Protocol-wrapped Supabase Auth: view models and previews depend on this
//  protocol and plain Sendable types only, never on the Supabase package
//  directly, so a Mock implementation can stand in for previews/tests.
//

import Foundation

/// The signed-in account. Deliberately minimal for Phase 1 — an avatar and
/// any other profile data live in the `profiles` table and are read
/// separately once a profile-fetching use case exists. `fullName` is the one
/// exception: it's captured at sign-up (see the Sign Up screen's "Full name"
/// field) and stored as Supabase Auth user metadata, so it's already
/// available on the session/user object with no extra round-trip.
struct AuthUser: Identifiable, Hashable, Sendable {
    let id: UUID
    let email: String?
    let fullName: String?

    init(id: UUID, email: String?, fullName: String? = nil) {
        self.id = id
        self.email = email
        self.fullName = fullName
    }
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
    /// Sign-in was rejected because this account was never verified after
    /// signing up (Supabase's "Confirm email" project setting is on). Kept
    /// distinct from `.signInFailed` so the UI can route to the OTP screen
    /// instead of just showing an error message.
    case emailNotConfirmed(email: String)
    case otpVerificationFailed(underlying: String)
    case otpResendFailed(underlying: String)

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
        case .emailNotConfirmed:
            "Please verify your email before signing in."
        case .otpVerificationFailed(let underlying):
            "Couldn't verify that code: \(underlying)"
        case .otpResendFailed(let underlying):
            "Couldn't resend the code: \(underlying)"
        }
    }
}

/// What happens right after `AuthService.signUp` succeeds depends on this
/// Supabase project's "Confirm email" setting: if it's on (recommended, and
/// the assumed default here), there's no session yet and the UI must show
/// the OTP screen before the account is actually usable.
enum SignUpResult: Sendable {
    case signedIn(AuthUser)
    case verificationRequired(email: String)
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

    func signUp(email: String, password: String, fullName: String) async throws -> SignUpResult
    /// Throws `AuthError.emailNotConfirmed` (not `.signInFailed`) if this
    /// account signed up but never completed OTP verification.
    func signIn(email: String, password: String) async throws -> AuthUser

    /// Verifies the 6-digit code from Supabase's "Confirm signup" email
    /// (see `SignUpResult.verificationRequired` / `AuthError.emailNotConfirmed`)
    /// and returns the now-signed-in user.
    func verifyOTP(email: String, token: String) async throws -> AuthUser

    /// Re-sends that same confirmation code -- used for an explicit "Resend"
    /// tap on the OTP screen, and automatically when a sign-in attempt
    /// reveals the account was never verified in the first place.
    func resendVerificationCode(email: String) async throws

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
