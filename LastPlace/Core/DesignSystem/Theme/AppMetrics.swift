//
//  AppMetrics.swift
//  LastPlace
//
//  Shared corner radii and the card shadow used across the redesign. The
//  mock's card shadow is two stacked shadows (a tight one plus a soft,
//  spread one) — `View.appCardShadow()` applies both together so call
//  sites don't have to repeat the pair.
//

import SwiftUI

enum AppMetrics {
    static let cardRadius: CGFloat = 20
    static let plateRadius: CGFloat = 14
    static let tabBarRadius: CGFloat = 32
    static let tabBarHeight: CGFloat = 64
}

extension View {
    /// The two-layer elevation shadow used on every card/sheet surface in
    /// the redesign — a tight contact shadow plus a soft ambient one.
    func appCardShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
            .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 14)
    }
}
