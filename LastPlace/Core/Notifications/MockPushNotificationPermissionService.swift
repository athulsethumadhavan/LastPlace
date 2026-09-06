//
//  MockPushNotificationPermissionService.swift
//  LastPlace
//
//  No-op stand-in for previews/`makePreview()` -- never triggers a real
//  system permission prompt.
//

import Foundation

struct MockPushNotificationPermissionService: PushNotificationPermissionService {
    func requestAuthorizationAndRegisterIfNeeded() async {}
}
