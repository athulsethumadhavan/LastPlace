//
//  ShareRoomViewModel.swift
//  LastPlace
//
//  Owner side of Phase 4 sharing: invite a registered LastPlace user by
//  email to view this room, see who it's currently shared with, and revoke
//  access. Reads/writes Supabase directly through `RoomSharingService` —
//  there's no local cache or `SyncEngine` involvement here.
//

import Foundation
import Observation

/// One row in the "shared with" list: a share plus (best-effort) the
/// recipient's profile, so the UI can show their name/email instead of a
/// bare UUID.
struct OutgoingShareSummary: Identifiable, Sendable {
    let share: RoomShare
    let profile: SharingProfile?
    var id: UUID { share.id }
}

@Observable
@MainActor
final class ShareRoomViewModel {
    let roomID: UUID
    private(set) var state: LoadableState<[OutgoingShareSummary]> = .idle
    var inviteEmail: String = ""
    private(set) var isInviting: Bool = false
    var inviteError: UserFacingError?
    private(set) var mutatingShareID: UUID?

    private let roomSharingService: RoomSharingService
    /// See `invite()` -- the `share_room` RPC validates room ownership
    /// server-side, so a room that exists only in local SwiftData has to be
    /// pushed first.
    private let syncEngine: PendingChangesSyncing
    private let authService: AuthService
    private let imageStorage: ImageStorageService
    private let analytics: AnalyticsService
    private let logger: AppLogger

    init(
        roomID: UUID,
        roomSharingService: RoomSharingService,
        syncEngine: PendingChangesSyncing,
        authService: AuthService,
        imageStorage: ImageStorageService,
        analytics: AnalyticsService,
        logger: AppLogger
    ) {
        self.roomID = roomID
        self.roomSharingService = roomSharingService
        self.syncEngine = syncEngine
        self.authService = authService
        self.imageStorage = imageStorage
        self.analytics = analytics
        self.logger = logger
    }

    var canInvite: Bool {
        !isInviting && isPlausibleEmail(inviteEmail)
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        await refresh()
    }

    func invite() {
        guard canInvite else { return }
        let email = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        isInviting = true
        inviteError = nil
        Task {
            defer { isInviting = false }
            do {
                // Same reason as `GiftsViewModel.accept` -- this room may
                // have been created locally and not pushed yet, in which
                // case the server-side ownership check can't see it.
                if let userID = await authService.currentUser?.id {
                    try? await syncEngine.sync(userID: userID, imageStorage: imageStorage)
                }
                _ = try await roomSharingService.inviteToRoom(roomID: roomID, inviteeEmail: email)
                // No parameters -- deliberately not the invitee's email.
                analytics.log(.roomShared)
                inviteEmail = ""
                await refresh()
            } catch {
                logger.error("Room invite failed", error: error, category: "sharing")
                inviteError = UserFacingError.from(error)
            }
        }
    }

    func revoke(_ shareID: UUID) {
        guard mutatingShareID == nil else { return }
        mutatingShareID = shareID
        Task {
            defer { mutatingShareID = nil }
            do {
                try await roomSharingService.removeShare(shareID)
                await refresh()
            } catch {
                logger.error("Revoking room share failed", error: error, category: "sharing")
                inviteError = UserFacingError.from(error)
            }
        }
    }

    private func refresh() async {
        do {
            let shares = try await roomSharingService.outgoingShares(roomID: roomID)
            let roomSharingService = self.roomSharingService
            let summaries = await withTaskGroup(of: OutgoingShareSummary.self) { group in
                for share in shares {
                    group.addTask {
                        let profile = try? await roomSharingService.fetchProfile(userID: share.sharedWithUserID)
                        return OutgoingShareSummary(share: share, profile: profile ?? nil)
                    }
                }
                var results: [OutgoingShareSummary] = []
                for await summary in group { results.append(summary) }
                return results
            }
            state = .loaded(summaries.sorted { $0.share.invitedAt > $1.share.invitedAt })
        } catch {
            logger.error("Loading room shares failed", error: error, category: "sharing")
            state = .failed(UserFacingError.from(error))
        }
    }

    private func isPlausibleEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let atIndex = trimmed.firstIndex(of: "@") else { return false }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        return domain.contains(".")
    }
}
