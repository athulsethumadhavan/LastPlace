//
//  AsyncTestHelpers.swift
//  LastPlaceTests
//
//  A handful of view model methods fire an internal `Task { ... }` from a
//  non-`async` function (the right shape for a button/action handler that a
//  SwiftUI view calls without `await`), rather than exposing the work as an
//  `async` function the caller can await directly. A test can't `await`
//  those trigger methods, so this polls a MainActor-isolated condition
//  until it flips or a timeout elapses -- the standard workaround for
//  exactly this shape.
//

import Foundation
import XCTest

@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("Timed out waiting for condition", file: file, line: line)
            return
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}
