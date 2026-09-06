//
//  AppConfiguration.swift
//  LastPlace
//
//  Tunables that shouldn't be scattered as magic numbers across the codebase.
//

import Foundation

struct AppConfiguration: Sendable {
    let splashMinimumDuration: TimeInterval
    let recentItemsLimit: Int
    let searchSuggestedLimit: Int

    static let `default` = AppConfiguration(
        splashMinimumDuration: 0.6,
        recentItemsLimit: 8,
        searchSuggestedLimit: 12
    )
}
