//
//  FetchHomesUseCase.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol FetchHomesUseCase: Sendable {
    func execute() async throws -> [Home]
}

struct DefaultFetchHomesUseCase: FetchHomesUseCase {
    let homeRepository: HomeRepository

    func execute() async throws -> [Home] {
        try await homeRepository.fetchHomes()
    }
}
