//
//  FirebaseAnalyticsService.swift
//  LastPlace
//
//  The only file in the app that imports FirebaseAnalytics. Everything
//  else goes through `AnalyticsService`.
//
//  VERIFY-BEFORE-TRUST: `Analytics.logEvent(_:parameters:)` is the stable,
//  long-standing Firebase Analytics API, but this hasn't been built
//  against the SDK in this session -- confirm the import resolves and that
//  FirebaseAnalytics is in the app target's package products.
//

import Foundation
import FirebaseAnalytics

struct FirebaseAnalyticsService: AnalyticsService {
    func log(_ event: AnalyticsEvent) {
        // `FirebaseApp.configure()` runs in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`,
        // which is guaranteed to have completed before any view model that
        // could call this exists.
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}
