//
//  OnboardingPage.swift
//  LastPlace
//

import Foundation

struct OnboardingPage: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let symbolName: String

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        symbolName: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
    }

    static let defaultPages: [OnboardingPage] = [
        OnboardingPage(
            title: "Save where things were last seen",
            subtitle: "Snap a photo and note the spot — passport in the top drawer, charger on the desk.",
            symbolName: "camera.viewfinder"
        ),
        OnboardingPage(
            title: "Find anything in seconds",
            subtitle: "Search by name, room, or where you last put it. LastPlace remembers so you don't have to.",
            symbolName: "sparkle.magnifyingglass"
        ),
        OnboardingPage(
            title: "Everything stays on your device",
            subtitle: "Your photos and notes never leave this phone. Private by default.",
            symbolName: "lock.shield"
        )
    ]
}
