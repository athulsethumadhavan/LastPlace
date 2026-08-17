//
//  SystemPushNotificationPermissionService.swift
//  LastPlace
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session. `UNUserNotificationCenter.notificationSettings()`/
//  `.requestAuthorization(options:)` are the standard async APIs (iOS
//  15+); `UIApplication.registerForRemoteNotifications()` is
//  main-actor-isolated by the SDK itself, hence `@MainActor` on this type.
//

import UIKit
import UserNotifications

@MainActor
final class SystemPushNotificationPermissionService: PushNotificationPermissionService {
    func requestAuthorizationAndRegisterIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            settings = await center.notificationSettings()
        }

        switch settings.authorizationStatus {
        case .denied:
            // Respect an explicit prior decline -- don't re-prompt or
            // register a token that has nowhere useful to be delivered.
            return
        default:
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
