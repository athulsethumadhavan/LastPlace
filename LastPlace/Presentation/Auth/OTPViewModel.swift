//
//  OTPViewModel.swift
//  LastPlace
//

import Foundation
import Observation

@Observable
@MainActor
final class OTPViewModel {
    let email: String
    var code: String = "" {
        didSet {
            let filtered = String(code.prefix(6).filter(\.isNumber))
            if filtered != code { code = filtered }
        }
    }
    var isLoading: Bool = false
    var errorMessage: String?
    /// Seconds left before "Resend" is tappable again. Counts down via a
    /// detached `Task` that captures `self` weakly and re-checks it on every
    /// tick rather than unwrapping once, so it can't extend this object's
    /// lifetime -- no `deinit`/cancellation bookkeeping needed as a result.
    var resendCooldown: Int = 0

    private let authService: AuthService
    private let onVerified: @MainActor (AuthUser) -> Void

    init(email: String, authService: AuthService, onVerified: @escaping @MainActor (AuthUser) -> Void) {
        self.email = email
        self.authService = authService
        self.onVerified = onVerified
        startCooldown()
    }

    var canSubmit: Bool {
        code.count == 6 && !isLoading
    }

    func submit() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let user = try await authService.verifyOTP(email: email, token: code)
                onVerified(user)
            } catch {
                errorMessage = error.localizedDescription
                code = ""
            }
        }
    }

    func resend() {
        guard resendCooldown == 0, !isLoading else { return }
        errorMessage = nil
        Task {
            do {
                try await authService.resendVerificationCode(email: email)
                startCooldown()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startCooldown() {
        resendCooldown = 30
        Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                guard self.resendCooldown > 0 else { return }
                self.resendCooldown -= 1
            }
        }
    }
}
