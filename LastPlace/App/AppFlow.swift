//
//  AppFlow.swift
//  LastPlace
//

import Foundation

enum AppFlow: Hashable {
    case splash
    case onboarding
    case locked
    case main
    case failed(reason: String)
}
