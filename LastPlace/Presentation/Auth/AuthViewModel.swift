//
//  AuthViewModel.swift
//  LastPlace
//

import AuthenticationServices
import Foundation
import Observation

enum AuthMode {
    case signIn
    case signUp

    var toggled: AuthMode { self == .signIn ? .signUp : .signIn }
    var primaryButtonTitle: String { self == .signIn ? "Sign In" : "Create Account" }
    var headline: String { self == .signIn ? "Welcome back" : "Create account" }
    var subheadline: String {
        self == .signIn
            ? "Sign in to sync your rooms and items."
            : "Start keeping track of everything you own."
    }
    var toggleQuestion: String { self == .signIn ? "Don't have an account?" : "Already have an account?" }
    var toggleActionTitle: String { self == .signIn ? "Sign Up" : "Sign In" }
}

extension AuthMode: Equatable {}

@Observable
@MainActor
final class AuthViewModel {
    var mode: AuthMode = .signIn
    var fullName: String = ""
    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    /// Set whenever `submit()` discovers the account needs OTP verification
    /// -- either fresh off `signUp` (no session yet), or because a `signIn`
    /// attempt revealed the account was never verified in the first place.
    /// `AuthView` presents `OTPView` for as long as this is non-nil.
    var pendingVerificationEmail: String?

    /// Set on each attempt to satisfy Sign in with Apple's replay-protection
    /// requirement -- generated fresh per request, never reused.
    private var currentAppleNonce: String?

    private let authService: AuthService
    private let onAuthenticated: @MainActor (AuthUser) -> Void

    init(authService: AuthService, onAuthenticated: @escaping @MainActor (AuthUser) -> Void) {
        self.authService = authService
        self.onAuthenticated = onAuthenticated
    }

    var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, password.count >= 6, !isLoading else {
            return false
        }
        guard mode == .signUp else { return true }
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && confirmPassword == password
    }

    /// Only meaningful once someone's typed a `confirmPassword` -- surfaced
    /// as inline help rather than folded into `errorMessage`, so it clears
    /// itself the moment the two fields match instead of lingering like a
    /// server error would.
    var passwordMismatch: Bool {
        mode == .signUp && !confirmPassword.isEmpty && confirmPassword != password
    }

    func toggleMode() {
        mode = mode.toggled
        errorMessage = nil
    }

    func submit() {
        guard canSubmit else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                switch mode {
                case .signIn:
                    let user = try await authService.signIn(email: trimmedEmail, password: password)
                    onAuthenticated(user)
                case .signUp:
                    switch try await authService.signUp(email: trimmedEmail, password: password, fullName: trimmedName) {
                    case .signedIn(let user):
                        onAuthenticated(user)
                    case .verificationRequired(let verificationEmail):
                        pendingVerificationEmail = verificationEmail
                    }
                }
            } catch AuthError.emailNotConfirmed(let unverifiedEmail) {
                // A fresh code beats relying on whatever was sent at signup
                // -- that one may have already expired or gone unread.
                // Best-effort: even if the resend itself fails, still route
                // to the OTP screen so "Resend" is right there to retry.
                try? await authService.resendVerificationCode(email: unverifiedEmail)
                pendingVerificationEmail = unverifiedEmail
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Called once `OTPView` confirms the code -- clears the pending state
    /// so the cover dismisses, then hands off exactly like a normal sign-in.
    func completeVerification(_ user: AuthUser) {
        pendingVerificationEmail = nil
        onAuthenticated(user)
    }

    /// Called from `SignInWithAppleButton`'s `onRequest` closure to attach the
    /// hashed nonce to the outgoing Apple authorization request.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInNonce.random()
        currentAppleNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = AppleSignInNonce.sha256(nonce)
    }

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let user = try await authService.signInWithGoogle()
                onAuthenticated(user)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Called from `SignInWithAppleButton`'s `onCompletion` closure.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        guard let nonce = currentAppleNonce else {
            errorMessage = AuthError.appleSignInFailed(underlying: "Missing nonce.").errorDescription
            return
        }
        currentAppleNonce = nil

        switch result {
        case .failure(let error):
            // The system presents its own cancel/error UI for most cases;
            // avoid piling on with a redundant alert for a user-initiated cancel.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = AuthError.appleSignInFailed(underlying: error.localizedDescription).errorDescription
            }
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = AuthError.appleSignInFailed(underlying: "No identity token returned.").errorDescription
                return
            }

            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    let user = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                    onAuthenticated(user)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
