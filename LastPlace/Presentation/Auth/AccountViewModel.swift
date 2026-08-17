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
    /// Only used by `signOut()`, to drop this device's push token before
    /// the session goes away -- see that method's doc comment.
    private let deviceTokenService: DeviceTokenService
    private let onSignedOut: @MainActor () -> Void
    private let observationTaskBox = TaskBox()

    init(
        authService: AuthService,
        deviceTokenService: DeviceTokenService,
        onSignedOut: @escaping @MainActor () -> Void
    ) {
        self.authService = authService
        self.deviceTokenService = deviceTokenService
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

    /// Drops this device's push token *before* ending the session, not
    /// after: the `device_tokens` delete is RLS-scoped to `auth.uid()`, so
    /// once the session is gone the row can no longer be deleted by this
    /// client at all. Without this, signing out on a shared device leaves
    /// the row behind and the next person to use it keeps receiving the
    /// previous account's notifications.
    ///
    /// Best-effort (`try?`): a failed unregister shouldn't block the
    /// sign-out the person actually asked for. Worst case the row lingers
    /// until that token is reissued to another account, at which point the
    /// `token`-unique upsert in `registerToken` reassigns it.
    func signOut() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            // Deletes the server-side row but deliberately keeps the relay's
            // retained copy: an FCM token identifies this *install*, not the
            // account, and Firebase won't hand it over again unless it
            // actually rotates. Discarding it here would leave the next
            // sign-in with nothing to register, silently making that account
            // unreachable by push -- see
            // `AppCoordinator.registerPushTokenIfAvailable`.
            if let token = PushNotificationRelay.shared.currentFCMToken {
                try? await deviceTokenService.unregisterToken(token)
            }
            do {
                try await authService.signOut()
                onSignedOut()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// No explicit token cleanup needed here, unlike `signOut()`:
    /// `device_tokens.user_id` is declared `references auth.users(id) on
    /// delete cascade`, so deleting the account takes every one of that
    /// user's token rows with it server-side -- including rows belonging to
    /// their *other* devices, which a client-side delete couldn't reach
    /// anyway.
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
