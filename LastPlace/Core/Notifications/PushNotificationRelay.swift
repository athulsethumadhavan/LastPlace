//
//  PushNotificationRelay.swift
//  LastPlace
//
//  `AppDelegate` is created by `@UIApplicationDelegateAdaptor` before
//  `AppDependencyContainer`/`AppCoordinator` exist (those are built lazily
//  inside `LastPlaceApp`'s `.task`, per `AppBootstrap`), so it has no way to
//  reach the services it'd need to act on an APNs event directly. This is
//  the bridge: `AppDelegate` forwards raw events here, and whichever part
//  of the app is ready to act on them (once the container exists) sets the
//  corresponding closure. A deliberate, narrow exception to "no
//  singletons" -- same rationale as `SupabaseClientProvider.shared` -- not
//  a pattern to reach for elsewhere.
//
//  Events that arrive before their closure is set (a cold launch triggered
//  by tapping a notification, for instance, fires before `RootView`'s
//  `.task` has finished building anything) are buffered rather than
//  dropped, and replayed once `flushPending()` is called after the
//  closures are wired up.
//

import Foundation

/// Where tapping a notification should land. Mirrors the `route` value the
/// `notify-item-update` Edge Function puts in the FCM `data` payload.
enum PushNotificationDestination: Sendable, Equatable {
    /// A specific item in *this* account. Sent for `item_location_update`,
    /// where the id is the notified user's own copy of the gifted item --
    /// resolved server-side via `item_gifts.item_id`, not the other
    /// account's row, which this device could never load.
    case item(id: UUID)
    /// The Gifts screen -- sent for `gift_received` (no item exists on this
    /// device yet, only a pending gift to accept) and `gift_accepted`.
    case gifts
}

@MainActor
final class PushNotificationRelay {
    static let shared = PushNotificationRelay()
    private init() {}

    /// Set once `AppDependencyContainer` exists. Given the actual FCM
    /// registration token from `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)`
    /// -- not the raw APNs token, which `AppDelegate` hands off to
    /// `Messaging` directly and never routes through here. This is what
    /// `DeviceTokenService.registerToken` persists. Fires once at launch
    /// and again any time FCM rotates the token, so the consumer should
    /// treat every call as "register this," not just the first one.
    var onFCMTokenReceived: ((String) -> Void)?
    var onRegistrationFailed: ((Error) -> Void)?

    /// The most recent FCM token this device has been issued, retained so
    /// sign-out can unregister *this* device's row from `device_tokens`
    /// (see `AccountViewModel.signOut`) without having to ask Firebase for
    /// it again asynchronously mid-sign-out.
    private(set) var currentFCMToken: String?

    /// Set once `MainTabCoordinator` exists, to navigate where the tapped
    /// notification points. See `MainTabView.makeCoordinator`.
    var onNotificationTapped: ((PushNotificationDestination) -> Void)?

    private var pendingFCMToken: String?
    private var pendingDestination: PushNotificationDestination?

    func fcmTokenReceived(_ token: String) {
        currentFCMToken = token
        guard let onFCMTokenReceived else {
            pendingFCMToken = token
            return
        }
        onFCMTokenReceived(token)
    }

    // Note: there is deliberately no `clearCurrentFCMToken()`. An earlier
    // version cleared this on sign-out, which seemed tidy but broke push
    // for the next account: the token identifies this *install*, and
    // Firebase only re-delivers it when it actually rotates, so once
    // discarded there was nothing left to register at the next sign-in.
    // Sign-out deletes the `device_tokens` row; the token itself stays.

    func registrationFailed(_ error: Error) {
        onRegistrationFailed?(error)
    }

    func notificationTapped(_ destination: PushNotificationDestination) {
        guard let onNotificationTapped else {
            pendingDestination = destination
            return
        }
        onNotificationTapped(destination)
    }

    /// Call after wiring the closures above (see `MainTabView.makeCoordinator`)
    /// to replay anything that arrived first.
    func flushPending() {
        if let pendingFCMToken {
            self.pendingFCMToken = nil
            onFCMTokenReceived?(pendingFCMToken)
        }
        if let pendingDestination {
            self.pendingDestination = nil
            onNotificationTapped?(pendingDestination)
        }
    }
}
