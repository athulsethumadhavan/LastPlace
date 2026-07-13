//
//  FetchDefaultHomeUseCase.swift
//  LastPlace
//

import Foundation

protocol FetchDefaultHomeUseCase: Sendable {
    func execute() async throws -> Home
}

struct DefaultFetchDefaultHomeUseCase: FetchDefaultHomeUseCase {
    let homeRepository: HomeRepository

    func execute() async throws -> Home {
        try await homeRepository.fetchDefaultHome()
    }
}
