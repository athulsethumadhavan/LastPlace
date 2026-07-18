//
//  HomeDashboardContent.swift
//  LastPlace
//

import Foundation

struct HomeDashboardContent: Sendable {
    let home: Home
    let rooms: [Room]
    let recentItems: [StoredItem]
    let importantItems: [StoredItem]

    var isFullyEmpty: Bool {
        rooms.isEmpty && recentItems.isEmpty && importantItems.isEmpty
    }
}
