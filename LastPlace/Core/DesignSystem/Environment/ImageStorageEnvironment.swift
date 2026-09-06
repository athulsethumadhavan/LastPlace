//
//  ImageStorageEnvironment.swift
//  LastPlace
//
//  Threads the `ImageStorageService` through SwiftUI so `AsyncStoredImage` can
//  render anywhere without every view having to plumb the dependency manually.
//  RootView injects the real service; previews inject a mock.
//

import SwiftUI

private struct ImageStorageKey: EnvironmentKey {
    static let defaultValue: (any ImageStorageService)? = nil
}

extension EnvironmentValues {
    var imageStorage: (any ImageStorageService)? {
        get { self[ImageStorageKey.self] }
        set { self[ImageStorageKey.self] = newValue }
    }
}
