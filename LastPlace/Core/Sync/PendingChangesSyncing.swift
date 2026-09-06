//
//  PendingChangesSyncing.swift
//  LastPlace
//
//  A one-method view onto `SyncEngine`, for the view models that need to
//  flush local changes to Postgres before calling a server-side RPC that
//  validates against them (see `GiftsViewModel.accept`,
//  `GiftItemViewModel.send`, `ShareRoomViewModel.invite` -- all three fail
//  with a confusing "not owned by caller" error if the row they reference
//  exists only in local SwiftData).
//
//  Why this exists at all: `SyncEngine` is the one service
//  `AppDependencyContainer` doesn't take through `init`, and its comment
//  there justified that on the grounds that nothing in a preview ever
//  calls `sync()`. That stopped being true once those view models started
//  calling it -- and `@ModelActor`'s generated initializer isn't something
//  a `#Preview` can usefully construct anyway. Wrapping it in a protocol
//  brings it in line with every other service here (real + Mock pair) and
//  keeps previews from needing a live `ModelContainer`.
//
//  Deliberately narrower than `SyncEngine`'s full surface: callers get
//  "flush pending changes" and nothing else, so a view model can't reach
//  for sync internals it has no business touching.
//

import Foundation

protocol PendingChangesSyncing: Sendable {
    /// Pushes local `.pendingUpsert`/`.pendingDelete` rows (and referenced
    /// images) up, then pulls remote rows down. Callers generally treat
    /// failure as non-fatal -- see the call sites, which use `try?` and let
    /// the subsequent RPC produce the user-facing error.
    func sync(userID: UUID, imageStorage: ImageStorageService) async throws
}

/// `SyncEngine.sync(userID:imageStorage:)` already matches the requirement
/// exactly, so this needs no members of its own.
extension SyncEngine: PendingChangesSyncing {}
