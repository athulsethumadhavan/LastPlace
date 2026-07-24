//
//  SharedRoomsViewModel.swift
//  LastPlace
//
//  Recipient side of Phase 4 sharing: rooms another LastPlace account has
//  shared with you, pending invites you can accept or decline, and
//  previously-accepted rooms you can open (read-only). Reads live from
//  Supabase via `RoomSharingService` — nothing here touches SwiftData.
//

import Foundation
import Observation

/// One incoming share plus (best-effort) the room name/icon and the
/// owner's profile, so the list doesn't have to show bare UUIDs. Either
/// lookup can come back nil if the underlying fetch failed — the row still
/// renders, just with a generic label.
struct IncomingShareSummary: Identifiable, Sendable {
    let share: RoomShare
    let room: Room?
    let ownerProfile: SharingProfile?
    var id: UUID { share.id }
}

@Observable
@MainActor
final class SharedRoomsViewModel {
    private(set) var state: LoadableState<[IncomingShareSummary]> = .idle
    private(set) var mutatingShareID: UUID?
    var actionError: UserFacingError?

    private let roomSharingService: RoomSharingService
    private let logger: AppLogger

    init(roomSharingService: RoomSharingService, logger: AppLogger) {
        self.roomSharingService = roomSharingService
        self.logger = logger
    }

    var pending: [IncomingShareSummary] {
        (state.value ?? []).filter { !$0.share.isAccepted }
    }

    var accepted: [IncomingShareSummary] {
        (state.value ?? []).filter { $0.share.isAccepted }
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        await refresh()
    }

    func accept(_ shareID: UUID) {
        guard mutatingShareID == nil else { return }
        mutatingShareID = shareID
        Task {
            defer { mutatingShareID = nil }
            do {
                try await roomSharingService.acceptShare(shareID)
                await refresh()
            } catch {
                logger.error("Accepting room share failed", error: error, category: "sharing")
                actionError = UserFacingError.from(error)
            }
        }
    }

    /// Used for both declining a pending invite and leaving an
    /// already-accepted share — both are just "delete my row".
    func decline(_ shareID: UUID) {
        guard mutatingShareID == nil else { return }
        mutatingShareID = shareID
        Task {
            defer { mutatingShareID = nil }
            do {
                try await roomSharingService.removeShare(shareID)
                await refresh()
            } catch {
                logger.error("Removing room share failed", error: error, category: "sharing")
                actionError = UserFacingError.from(error)
            }
        }
    }

    private func refresh() async {
        do {
            let shares = try await roomSharingService.incomingShares()
            let roomSharingService = self.roomSharingService
            let summaries = await withTaskGroup(of: IncomingShareSummary.self) { group in
                for share in shares {
                    group.addTask {
                        let detail = try? await roomSharingService.fetchSharedRoomDetail(roomID: share.roomID)
                        let profile = try? await roomSharingService.fetchProfile(userID: share.ownerID)
                        return IncomingShareSummary(share: share, room: detail?.room, ownerProfile: profile)
                    }
                }
                var results: [IncomingShareSummary] = []
                for await summary in group { results.append(summary) }
                return results
            }
            state = .loaded(summaries.sorted { $0.share.invitedAt > $1.share.invitedAt })
        } catch {
            logger.error("Loading incoming shares failed", error: error, category: "sharing")
            state = .failed(UserFacingError.from(error))
        }
    }
}
