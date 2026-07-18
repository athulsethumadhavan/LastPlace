//
//  AppFont.swift
//  LastPlace
//
//  The design doc specifies "Lora" (an editorial serif) for headings over a
//  plain sans body font. Lora isn't bundled with iOS, and bundling the
//  actual font files would mean adding assets + an Info.plist registration
//  step in Xcode with no compiler here to verify it — so headings use
//  `.serif` design instead, which resolves to New York, Apple's own
//  editorial serif. Close in spirit, zero asset risk.
//

import SwiftUI

enum AppFont {
    /// Section titles, screen titles, card names — anywhere the mock uses
    /// Lora at `font-weight:600`.
    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Body copy, captions, labels — anywhere the mock uses the plain body
    /// font. This is just the system default design, spelled out for
    /// symmetry with `heading(_:weight:)`.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
