//
//  AppearanceViewModel.swift
//  LastPlace
//
//  Thin pass-through over `AppearanceSettingsStore` so the screen follows the
//  same coordinator → view model → view shape as the rest of Settings, even
//  though there's no async work here. The getter/setter both touch the
//  store's own `@Observable` storage, so Observation tracks straight through
//  this indirection — `AppearanceView` re-renders on change same as if it
//  read the store directly.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppearanceViewModel {
    private let store: AppearanceSettingsStore

    init(store: AppearanceSettingsStore) {
        self.store = store
    }

    var mode: AppearanceMode {
        get { store.mode }
        set { store.mode = newValue }
    }
}
