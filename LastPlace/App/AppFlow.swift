//
//  AppFlow.swift
//  LastPlace
//

import Foundation

enum AppFlow: Hashable {
    case splash
    case onboarding
    /// No Supabase session -- shown as a mandatory, non-dismissible gate
    /// before `.locked`/`.main` are ever reachable. Once someone signs in,
    /// their session persists automatically (the Supabase client's own
    /// Keychain storage), so this only reappears after an explicit sign-out
    /// or account deletion -- not on every launch.
    case authRequired
    case locked
    case main
    case failed(reason: String)
}
