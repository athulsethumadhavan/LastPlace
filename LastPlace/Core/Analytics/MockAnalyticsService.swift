//
//  MockAnalyticsService.swift
//  LastPlace
//
//  Records events instead of sending them, so previews never fire real
//  analytics and tests can assert on what was logged.
//

import Foundation

final class MockAnalyticsService: AnalyticsService, @unchecked Sendable {
    private(set) var loggedEvents: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        loggedEvents.append(event)
    }

    /// Convenience for assertions -- `AnalyticsEvent` isn't `Equatable`
    /// (its associated values would make that noisy to maintain), so tests
    /// generally want to match on the event name.
    func loggedEventNames() -> [String] {
        loggedEvents.map(\.name)
    }
}
