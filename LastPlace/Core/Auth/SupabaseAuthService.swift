//
//  SupabaseAuthService.swift
//  LastPlace
//
//  Concrete AuthService backed by supabase-swift's Auth client.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session. The overall shape (signUp/signIn/signOut, a `session` /
//  `authStateChanges` pair, `signInWithIdToken` for Sign in with Apple) is
//  stable across recent supabase-swift versions, but exact method/parameter
//  names have shifted between versions in the past. The moment the package
//  is added in Xcode, build this file first — Xcode's own autocomplete and
//  compiler errors are the fastest way to catch any drift and are more
//  trustworthy than this comment. Two spots added for the "Full name" field
//  are unverified the same way: `client.auth.signUp(email:password:data:)`
//  taking `data: [String: AnyJSON]`, and reading it back via
//  `user.userMetadata["full_name"]?.stringValue` -- if `stringValue` isn't
//  the right accessor, `AnyJSON`'s cases (`.string`, `.object`, etc.) are the
//  fallback to pattern-match on directly. Same caveat for the OTP additions:
//  `client.auth.verifyOTP(email:token:type:)` and
//  `client.auth.resend(email:type:)` with `type: .signup`, and the
//  string-matching used in `signIn` to detect an unconfirmed account (see
//  the comment inline there).
//

import Foundation
import GoogleSignIn
import Supabase
import UIKit

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
        // GIDSignIn is a process-wide singleton; this is the one place its
        // client ID gets configured, matching where every other Auth service
        // in this file resolves its own configuration.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: GoogleAuthConfig.iosClientID)
    }

    var currentUser: AuthUser? {
        get async {
            guard let session = try? await client.auth.session else { return nil }
            return AuthUser(session.user)
        }
    }

    var userChanges: AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            let task = Task {
                for await change in client.auth.authStateChanges {
                    continuation.yield(change.session.map { AuthUser($0.user) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signUp(email: String, password: String, fullName: String) async throws -> SignUpResult {
        do {
            // `data` lands in Supabase Auth's `raw_user_meta_data` -- no
            // separate `profiles` write needed just to remember a name.
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            // A session comes back immediately only if this project's
            // "Confirm email" setting is off. With it on (the assumed
            // default -- see the OTP screen this powers), `response.session`
            // is nil until `verifyOTP` succeeds.
            guard let session = response.session else {
                return .verificationRequired(email: email)
            }
            return .signedIn(AuthUser(session.user))
        } catch {
            throw AuthError.signUpFailed(underlying: error.localizedDescription)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthUser(session.user)
        } catch {
            // VERIFY-BEFORE-TRUST: matching on the error's message text is a
            // heuristic, not a typed case -- supabase-swift's Auth errors
            // don't expose a stable "email not confirmed" case as of this
            // writing. If a real unconfirmed-email sign-in attempt doesn't
            // land here, check what Xcode actually surfaces for that error
            // (likely an `AuthError` from the Supabase package, distinct
            // from this file's own `AuthError`) and match on its real code
            // instead of this string search.
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("email not confirmed")
                || message.localizedCaseInsensitiveContains("email_not_confirmed")
                || message.localizedCaseInsensitiveContains("not confirmed") {
                throw AuthError.emailNotConfirmed(email: email)
            }
            throw AuthError.signInFailed(underlying: message)
        }
    }

    func verifyOTP(email: String, token: String) async throws -> AuthUser {
        do {
            let response = try await client.auth.verifyOTP(email: email, token: token, type: .signup)
            guard let session = response.session else {
                throw AuthError.otpVerificationFailed(underlying: "No session was returned after verification.")
            }
            return AuthUser(session.user)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.otpVerificationFailed(underlying: error.localizedDescription)
        }
    }

    func resendVerificationCode(email: String) async throws {
        do {
            try await client.auth.resend(email: email, type: .signup)
        } catch {
            throw AuthError.otpResendFailed(underlying: error.localizedDescription)
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
            return AuthUser(session.user)
        } catch {
            throw AuthError.appleSignInFailed(underlying: error.localizedDescription)
        }
    }

    @MainActor
    func signInWithGoogle() async throws -> AuthUser {
        guard let presentingVC = UIApplication.shared.topmostViewController else {
            throw AuthError.googleSignInFailed(underlying: "No screen available to present sign-in from.")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.googleSignInFailed(underlying: "No identity token returned.")
            }
            let accessToken = result.user.accessToken.tokenString
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .google, idToken: idToken, accessToken: accessToken)
            )
            return AuthUser(session.user)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.googleSignInFailed(underlying: error.localizedDescription)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
            // Clears GIDSignIn's own cached Google session too, so a later
            // Google sign-in re-prompts for account choice instead of
            // silently reusing whatever was last selected.
            await MainActor.run { GIDSignIn.sharedInstance.signOut() }
        } catch {
            throw AuthError.signOutFailed(underlying: error.localizedDescription)
        }
    }

    func requestPasswordReset(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            throw AuthError.passwordResetFailed(underlying: error.localizedDescription)
        }
    }

    func deleteAccount() async throws {
        do {
            // No parameters needed -- the function identifies the caller
            // from their own JWT, which `functions.invoke` attaches
            // automatically using the client's current session.
            try await client.functions.invoke("delete-account")
            await MainActor.run { GIDSignIn.sharedInstance.signOut() }
        } catch {
            throw AuthError.accountDeletionFailed(underlying: error.localizedDescription)
        }
    }
}

private extension AuthUser {
    init(_ user: Auth.User) {
        self.init(id: user.id, email: user.email, fullName: user.userMetadata["full_name"]?.stringValue)
    }
}
