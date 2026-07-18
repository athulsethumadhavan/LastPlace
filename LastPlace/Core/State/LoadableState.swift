//
//  LoadableState.swift
//  LastPlace
//
//  Single enum a view model exposes instead of stacking loosely-related
//  Booleans (isLoading, hasError, isEmpty). Views render one case at a time.
//

import Foundation

enum LoadableState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(UserFacingError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: UserFacingError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}
