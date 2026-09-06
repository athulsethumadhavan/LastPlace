//
//  DeviceTokenService.swift
//  LastPlace
//
//  Phase 6 — Push Notifications. Registers/unregisters this device's FCM
//  registration token against the `device_tokens` table so
//  `notify-item-update` (Supabase Edge Function) knows where to send a
//  push for a given user. Reads/writes Supabase directly, same rationale
//  as `RoomSharingService`/`ItemGiftingService` -- there's nothing here to
//  mirror into local-cache-plus-sync, a device token isn't user-facing data.
//

import Foundation

enum DeviceTokenError: LocalizedError, Sendable {
    case notAuthenticated
    case registrationFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to register for notifications."
        case .registrationFailed(let underlying):
            return underlying
        }
    }
}

protocol DeviceTokenService: Sendable {
    /// Upserts this token for the current user, keyed on the token itself
    /// (unique) rather than user_id -- a user can have more than one
    /// device. Safe to call repeatedly with the same token (e.g. on every
    /// launch); a no-op change server-side beyond bumping `updated_at`.
    func registerToken(_ token: String, platform: String) async throws

    /// Best-effort cleanup -- called on sign-out so a stale token doesn't
    /// keep receiving another account's notifications on a shared device.
    func unregisterToken(_ token: String) async throws
}
