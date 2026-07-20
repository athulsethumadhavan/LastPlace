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
    var headline: String { self == .signIn ? "Welcome back" : "Create your account" }
    var toggleQuestion: String { self == .signIn ? "Don't have an account?" : "Already have an account?" }
    var toggleActionTitle: String { self == .signIn ? "Sign Up" : "Sign In" }
}

extension AuthMode: Equatable {}

@Observable
@MainActor
final class AuthViewModel {
    var mode: AuthMode = .signIn
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

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
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && !isLoading
    }

    func toggleMode() {
        mode = mode.toggled
        errorMessage = nil
    }

    func submit() {
        guard canSubmit else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let user: AuthUser
                switch mode {
                case .signIn:
                    user = try await authService.signIn(email: trimmedEmail, password: password)
                case .signUp:
                    user = try await authService.signUp(email: trimmedEmail, password: password)
                }
                onAuthenticated(user)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
