//
//  CreateHomeUseCase.swift
//  LastPlace
//
//  Created by AthulAppStation on 13/07/26.
//

import Foundation

protocol CreateHomeUseCase: Sendable {
    func execute(name: String) async throws -> Home
}

struct DefaultCreateHomeUseCase: CreateHomeUseCase {
    let homeRepository: HomeRepository

    func execute(name: String) async throws -> Home {
        let draft = Home(name: name)
        _ = try draft.validated()
        return try await homeRepository.create(name: draft.name)
    }
}
