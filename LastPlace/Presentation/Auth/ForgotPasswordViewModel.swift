//
//  ForgotPasswordViewModel.swift
//  LastPlace
//

import Foundation
import Observation

@Observable
@MainActor
final class ForgotPasswordViewModel {
    var email: String
    var isLoading: Bool = false
    var errorMessage: String?
    var didSend: Bool = false

    private let authService: AuthService

    init(authService: AuthService, prefillEmail: String = "") {
        self.authService = authService
        self.email = prefillEmail
    }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func submit() {
        guard canSubmit else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                try await authService.requestPasswordReset(email: trimmedEmail)
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
