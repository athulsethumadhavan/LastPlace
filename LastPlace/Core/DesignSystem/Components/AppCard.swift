//
//  AppCard.swift
//  LastPlace
//
//  Rounded material card used for room / item tiles across the app —
//  matches the "Classical" design system's card treatment: a flat surface
//  fill (no border), a soft two-layer elevation shadow, and a 20pt radius.
//

import SwiftUI

struct AppCard<Content: View>: View {
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                    .fill(AppColor.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
            .appCardShadow()
    }
}
