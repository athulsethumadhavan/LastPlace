//
//  ScanSession.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

struct ScanSession: Identifiable, Hashable, Sendable {
    let id: UUID
    var roomID: UUID
    var startedAt: Date
    var completedAt: Date?
    var capturedImagePaths: [String]
    var status: ScanSessionStatus

    init(
        id: UUID = UUID(),
        roomID: UUID,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        capturedImagePaths: [String] = [],
        status: ScanSessionStatus = .inProgress
    ) {
        self.id = id
        self.roomID = roomID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.capturedImagePaths = capturedImagePaths
        self.status = status
    }
}

enum ScanSessionStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case inProgress
    case completed
    case cancelled
}
