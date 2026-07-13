//
//  AppFlow.swift
//  LastPlace
//

import Foundation

enum AppFlow: Hashable {
    case splash
    case onboarding
    case main
    case failed(reason: String)
}
