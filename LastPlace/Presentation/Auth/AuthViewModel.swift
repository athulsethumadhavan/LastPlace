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
    private let analytics: AnalyticsService
    private let onAuthenticated: @MainActor (AuthUser) -> Void

    init(
        authService: AuthService,
        analytics: AnalyticsService,
        onAuthenticated: @escaping @MainActor (AuthUser) -> Void
    ) {
        self.authService = authService
        self.analytics = analytics
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
                    analytics.log(.signedIn(method: .email))
                    onAuthenticated(user)
                case .signUp:
                    switch try await authService.signUp(email: trimmedEmail, password: password, fullName: trimmedName) {
                    case .signedIn(let user):
                        analytics.log(.signedIn(method: .email))
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
        // `.fullName` has to be asked for here or Apple simply won't return
        // it -- this scope was previously `[.email]` only, which is why
        // every Apple account ended up with no name. Requesting it also
        // makes Apple show the editable name field on the consent sheet, so
        // the person chooses what to share.
        //
        // Note this only takes effect for people authorising for the first
        // time. Anyone who already signed in has been recorded as
        // authorised by Apple and gets nil regardless of scopes, until the
        // app is revoked under Settings > Apple Account > Sign in with Apple.
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
    }

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let user = try await authService.signInWithGoogle()
                analytics.log(.signedIn(method: .google))
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

            // Apple hands the name over exactly once, on the very first
            // authorization, and only here on the credential -- it is never
            // in the identity token. So if it isn't captured at this moment
            // it's gone for good: every later sign-in returns nil, and the
            // account is left with no name at all. Hence passing it
            // through rather than relying on Supabase to read it from the
            // JWT the way it can for Google.
            let fullName = Self.formattedName(from: credential.fullName)

            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    let user = try await authService.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        fullName: fullName
                    )
                    analytics.log(.signedIn(method: .apple))
                    onAuthenticated(user)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Joins Apple's `PersonNameComponents` into a display name, or `nil`
    /// if there's nothing usable.
    ///
    /// `nil` is the normal case on every sign-in after the first, and on
    /// accounts where the person declined to share their name -- both mean
    /// "don't overwrite what's already stored", not "clear it".
    private static func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter.localizedString(
            from: components,
            style: .default
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}
