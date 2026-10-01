//
//  TrackingPermission.swift
//  LastPlace
//
//  App Tracking Transparency for AdMob. Ads show either way -- declining
//  just means AdMob falls back to non-personalized ads instead of ones
//  based on cross-app tracking, never a reason to change anything else
//  about the ad slot itself.
//
//  Asked from Home's first appearance rather than at cold launch: Apple's
//  guidance is to ask once there's enough context for the prompt to make
//  sense, and launch (before someone has even signed in) is the least
//  contextual moment available.
//
//  VERIFY-BEFORE-TRUST: written without a compiler available in this
//  session, against `AppTrackingTransparency`'s standard
//  `ATTrackingManager.requestTrackingAuthorization(completionHandler:)`.
//

import AppTrackingTransparency

enum TrackingPermission {
    /// Safe to call as often as this is invoked (e.g. every time Home's
    /// `.task` runs) -- the `.notDetermined` check below means the actual
    /// system prompt only ever fires once per install, exactly as iOS
    /// itself would enforce even without this guard.
    static func requestIfNeeded() {
        // Never surface the system permission dialog during a UI test --
        // XCUITest can't dismiss it, and it would hang the run. Checked via
        // the raw launch argument rather than `UITestingSupport` since that
        // type only exists in Debug builds and this file doesn't otherwise
        // need to be.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }
}
