//
//  AccountViewModel.swift
//  LastPlace
//
//  Not wired into any navigation yet -- built now, alongside the rest of
//  Phase 1, so it's ready the moment the app gates behind sign-in. Reads
//  the current user from `authService.userChanges` rather than expecting
//  one to be passed in, since nothing upstream tracks "the signed-in user"
//  as app-wide state yet.
//

import Foundation
import Observation

/// `deinit` on an `@MainActor` class is always nonisolated, so it can't
/// touch a normal MainActor-isolated `var` directly -- not even a
/// `Sendable` one, since the *property storage itself* is what's isolated,
/// not just the value inside it. Boxing the task in its own small
/// `@unchecked Sendable` reference type sidesteps that: the box is held via
/// a `let` (safe to read from any isolation domain), and cancellation is
/// the only thing ever done to its contents from `deinit`, which is safe
/// on its own.
private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
    func cancel() { task?.cancel() }
}

@Observable
@MainActor
final class AccountViewModel {
    private(set) var user: AuthUser?
    var isLoading: Bool = false
    var errorMessage: String?

    private let authService: AuthService
    private let onSignedOut: @MainActor () -> Void
    private let observationTaskBox = TaskBox()

    init(authService: AuthService, onSignedOut: @escaping @MainActor () -> Void) {
        self.authService = authService
        self.onSignedOut = onSignedOut
        // `authService` is captured by value (not via `self`) so this task
        // never holds a strong reference back to `self` -- otherwise the
        // task would keep this view model alive for as long as the stream
        // keeps yielding, and `deinit` (which is what's supposed to cancel
        // the task) would never run.
        observationTaskBox.task = Task { [weak self, authService] in
            for await user in authService.userChanges {
                guard !Task.isCancelled else { return }
                self?.user = user
            }
        }
    }

    deinit {
        observationTaskBox.cancel()
    }

    func signOut() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await authService.signOut()
                onSignedOut()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteAccount() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await authService.deleteAccount()
                onSignedOut()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
