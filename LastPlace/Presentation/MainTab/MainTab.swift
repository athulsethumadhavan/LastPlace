//
//  MainTab.swift
//  LastPlace
//

import Foundation

enum MainTab: String, Hashable, CaseIterable, Identifiable {
    case home
    case search
    case checklists
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:       return "Home"
        case .search:     return "Search"
        case .checklists: return "Checklists"
        case .settings:   return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .home:       return "house.fill"
        case .search:     return "magnifyingglass"
        case .checklists: return "checklist"
        case .settings:   return "gearshape"
        }
    }
}
