//
//  MockDeviceTokenService.swift
//  LastPlace
//
//  In-memory DeviceTokenService for previews/`makePreview()`.
//

import Foundation

final class MockDeviceTokenService: DeviceTokenService, @unchecked Sendable {
    private(set) var registeredTokens: [String: String] = [:] // token -> platform

    func registerToken(_ token: String, platform: String) async throws {
        registeredTokens[token] = platform
    }

    func unregisterToken(_ token: String) async throws {
        registeredTokens.removeValue(forKey: token)
    }
}
