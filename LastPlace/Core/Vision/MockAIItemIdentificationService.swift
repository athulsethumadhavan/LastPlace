//
//  MockAIItemIdentificationService.swift
//  LastPlace
//
//  Deterministic stand-in for previews/tests, mirroring
//  `MockObjectDetectionService`.
//

import Foundation

struct MockAIItemIdentificationService: AIItemIdentificationService {
    var stubbed: AIItemIdentification?
    var shouldFail: Bool = false

    init(
        stubbed: AIItemIdentification? = MockAIItemIdentificationService.defaultStub,
        shouldFail: Bool = false
    ) {
        self.stubbed = stubbed
        self.shouldFail = shouldFail
    }

    func identifyItem(in imageData: Data) async throws -> AIItemIdentification {
        if shouldFail {
            throw AIItemIdentificationError.requestFailed(underlying: "Preview failure")
        }
        guard let stubbed else {
            throw AIItemIdentificationError.requestFailed(underlying: "No preview data")
        }
        return stubbed
    }

    static let defaultStub = AIItemIdentification(name: "Black Leather Wallet", category: .wallets, confidence: 0.9)
}
