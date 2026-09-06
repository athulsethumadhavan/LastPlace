//
//  HomeRepository.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol HomeRepository: Sendable {
    func fetchHomes() async throws -> [Home]
    /// Returns the current default home, creating one on first launch.
    func fetchDefaultHome() async throws -> Home
    func create(name: String) async throws -> Home
    func rename(homeID: UUID, to name: String) async throws -> Home
    func delete(homeID: UUID) async throws
}
