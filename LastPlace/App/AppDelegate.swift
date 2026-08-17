//
//  AppDelegate.swift
//  LastPlace
//
//  A minimal `UIApplicationDelegate`. SwiftUI's `App` protocol has no
//  scene-based equivalent hook for the URL/push callbacks below, so
//  `@UIApplicationDelegateAdaptor` in `LastPlaceApp` wires this in without
//  otherwise touching the SwiftUI app lifecycle.
//
//  Phase 6 — Push Notifications: this handles the APNs/FCM-level plumbing
//  (Firebase configuration, registration, foreground presentation, tap
//  routing). It has no dependencies of its own -- see `PushNotificationRelay`
//  for why, and for where these events actually get acted on once the rest
//  of the app exists.
//
//  VERIFY-BEFORE-TRUST: `FirebaseApp.configure()` and the `Messaging`
//  calls below are written against the standard FirebaseMessaging setup
//  (https://firebase.google.com/docs/cloud-messaging/ios/client) but
//  haven't been built against the actual SDK target in this session --
//  confirm `import FirebaseCore`/`import FirebaseMessaging` resolve once
//  the package is added.

import UIKit
import GoogleSignIn
import UserNotifications
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Reads GoogleService-Info.plist, which must already be added to
        // the app target -- crashes on launch if it's missing.
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Google's consent flow completes by reopening the app via the custom
    /// URL scheme registered in Info.plist (the reversed iOS OAuth client
    /// ID); GIDSignIn needs this callback routed to it to finish the flow.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// `PushNotificationPermissionService.requestAuthorizationAndRegisterIfNeeded()`
    /// calls `UIApplication.registerForRemoteNotifications()`, which
    /// asynchronously calls back in here (or the failure method below) once
    /// APNs actually issues a token. Handing that raw APNs token to
    /// `Messaging` is what makes Firebase turn around and call
    /// `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)` below
    /// with the actual FCM registration token -- that's the one
    /// `DeviceTokenService`/`notify-item-update` care about, not this one.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationRelay.shared.registrationFailed(error)
        }
    }
}

extension AppDelegate: MessagingDelegate {
    /// Fires once at launch (once APNs registration completes) and again
    /// any time FCM rotates the token. `PushNotificationRelay` forwards
    /// this to whichever part of the app is ready to persist it via
    /// `DeviceTokenService` -- see `MainTabView.makeCoordinator`.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            PushNotificationRelay.shared.fcmTokenReceived(fcmToken)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Shows the banner/sound/badge even while the app is in the
    /// foreground -- without this, a push that arrives while the app is
    /// already open is delivered silently.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Fired when the user taps the notification (from the lock screen,
    /// Notification Center, or the in-app banner). `notify-item-update`
    /// puts a `route` (and, for item routes, an `item_id`) in the FCM
    /// message's `data` payload, which `UNNotificationRequest.content.userInfo`
    /// exposes here.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let destination = Self.destination(from: userInfo) else { return }
        await MainActor.run {
            PushNotificationRelay.shared.notificationTapped(destination)
        }
    }

    /// Falls back to `.gifts` when a `route` is present but unrecognized,
    /// or when an item route arrives without a usable `item_id` -- landing
    /// somewhere plausible beats a tap that appears to do nothing. Returns
    /// `nil` only when there's no route at all, which means the push didn't
    /// come from this app's notify function.
    private static func destination(from userInfo: [AnyHashable: Any]) -> PushNotificationDestination? {
        guard let route = userInfo["route"] as? String else { return nil }
        switch route {
        case "item":
            if let idString = userInfo["item_id"] as? String, let id = UUID(uuidString: idString) {
                return .item(id: id)
            }
            return .gifts
        case "room":
            if let idString = userInfo["room_id"] as? String, let id = UUID(uuidString: idString) {
                return .room(id: id)
            }
            // No usable id -- Home at least lands somewhere with the room
            // in it, rather than a screen that can't show anything.
            return .sharedRooms
        case "shared_rooms":
            return .sharedRooms
        case "gifts":
            return .gifts
        default:
            return .gifts
        }
    }
}
