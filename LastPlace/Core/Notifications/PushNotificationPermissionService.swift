//
//  PushNotificationPermissionService.swift
//  LastPlace
//
//  Protocol-wrapped UserNotifications/UIKit, mirroring
//  `BiometricAuthenticator` -- so `AppCoordinator` never imports
//  `UserNotifications`/`UIKit` directly and previews/tests can inject a
//  no-op mock instead of triggering a real system permission prompt.
//

import Foundation

protocol PushNotificationPermissionService: Sendable {
    /// Requests notification permission if it's never been asked before,
    /// then calls `UIApplication.registerForRemoteNotifications()` as long
    /// as the user hasn't explicitly denied it. Registering is safe (and
    /// necessary) to call on every launch/sign-in, not just the first time
    /// -- it's how the app learns about a token refresh/rotation via
    /// `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    func requestAuthorizationAndRegisterIfNeeded() async
}
