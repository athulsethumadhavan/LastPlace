//
//  LastSignedInUserStore.swift
//  LastPlace
//
//  Remembers which account this device's local store currently holds data
//  for, so a sign-in by a *different* account can wipe it first.
//
//  This exists because the SwiftData entities are account-agnostic -- none
//  of them carries a `user_id`; ownership only appears when `SyncEngine`
//  stamps the signed-in user's id onto rows as it pushes them. That's fine
//  for one account per device, but on a switch it means the new user
//  inherits the previous user's rooms and items, and any of those rows
//  still marked `.pendingUpsert` get uploaded under the *new* user's id.
//  So this isn't only a stale-UI problem: without the wipe it silently
//  moves one person's private data into another person's account.
//
//  `UserDefaults` rather than the Keychain: this is a plain equality
//  marker, not a credential, and it should reset on uninstall exactly like
//  the local store it describes.
//

import Foundation

enum LastSignedInUserStore {
    private static let key = "com.lastplace.sync.lastSignedInUserID"
    private static let defaults = UserDefaults.standard

    static var userID: UUID? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    static func set(_ userID: UUID) {
        defaults.set(userID.uuidString, forKey: key)
    }
}

// Note: this type deliberately exposes only the stored value, not a
// "should I wipe?" helper. It briefly had a `belongsToDifferentUser(than:)`
// method that answered `false` whenever nothing was recorded -- correct for
// a pre-accounts install, but wrong for a device whose previous account
// signed in before this tracking existed, which is every real device at the
// moment the feature ships. That single case is the whole bug, and it
// can't be decided from `UserDefaults` alone: it needs to inspect
// `SyncStatus` on the local rows. So the decision lives in
// `SyncEngine.wipeLocalDataIfAccountChanged`, which can see both.
