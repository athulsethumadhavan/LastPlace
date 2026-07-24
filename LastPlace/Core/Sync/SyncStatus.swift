//
//  SyncStatus.swift
//  LastPlace
//
//  

import Foundation

enum SyncStatus: String, Sendable {
    case pendingUpsert
    case pendingDelete
    case synced
}
