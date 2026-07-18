//
//  AppColor.swift
//  LastPlace
//
//  Color tokens for the "Classical" design system — a calm blue accent over
//  warm neutral surfaces. Values are lifted directly from the design doc's
//  light/dark theme blocks (see the uploaded "LastPlace iPhone App.dc.html").
//
//  Every token is a dynamic `Color` built on `UIColor { traitCollection in }`,
//  so it resolves against whatever light/dark trait is active at render
//  time — including a manual override from `AppearanceSettingsStore`
//  (applied via `.preferredColorScheme` at the root), not just the system
//  setting. No extra wiring needed here.
//

import SwiftUI
import UIKit

enum AppColor {
    /// Screen background — the canvas everything else sits on.
    static let background = dynamic(light: 0xF2F4F9, dark: 0x12151B)

    /// "mat" in the design doc — image plate fills, icon banners, input
    /// field backgrounds. One step up from `background`.
    static let surface = dynamic(light: 0xE4EAF7, dark: 0x1C212B)

    /// Card/sheet fill — the mock uses the page background color for card
    /// surfaces too (cards read as "raised" purely via shadow, not a tint
    /// change), so this intentionally equals `background`.
    static let cardBackground = background

    static let textPrimary = dynamic(light: 0x161A21, dark: 0xEEF2F8)
    static let textSecondary = dynamicAlpha(light: 0x161A21, lightAlpha: 0.6, dark: 0xEEF2F8, darkAlpha: 0.62)
    static let textTertiary = dynamicAlpha(light: 0x161A21, lightAlpha: 0.38, dark: 0xEEF2F8, darkAlpha: 0.4)

    static let divider = dynamicAlpha(light: 0x161A21, lightAlpha: 0.12, dark: 0xEEF2F8, darkAlpha: 0.16)

    static let accent = dynamic(light: 0x3E7BFA, dark: 0x6FA0FF)
    static let accentSoft = dynamicAlpha(light: 0x3E7BFA, lightAlpha: 0.12, dark: 0x6FA0FF, darkAlpha: 0.18)
    static let accentSoft2 = dynamicAlpha(light: 0x3E7BFA, lightAlpha: 0.28, dark: 0x6FA0FF, darkAlpha: 0.32)

    /// Frosted background for the floating tab bar.
    static let glassBackground = dynamicAlpha(light: 0xFFFFFF, lightAlpha: 0.55, dark: 0x1C2028, darkAlpha: 0.55)
    static let glassBorder = dynamicAlpha(light: 0xFFFFFF, lightAlpha: 0.6, dark: 0xFFFFFF, darkAlpha: 0.14)

    /// UIKit-facing counterpart to `textTertiary`, for the handful of spots
    /// (like `UITabBarAppearance`) that only take `UIColor`, not SwiftUI's
    /// `Color`. Same dynamic light/dark provider as the `Color` version.
    static let textTertiaryUIColor = dynamicAlphaUIColor(light: 0x161A21, lightAlpha: 0.38, dark: 0xEEF2F8, darkAlpha: 0.4)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(dynamicUIColor(light: light, dark: dark))
    }

    private static func dynamicAlpha(light: UInt32, lightAlpha: CGFloat, dark: UInt32, darkAlpha: CGFloat) -> Color {
        Color(dynamicAlphaUIColor(light: light, lightAlpha: lightAlpha, dark: dark, darkAlpha: darkAlpha))
    }

    private static func dynamicUIColor(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }

    private static func dynamicAlphaUIColor(light: UInt32, lightAlpha: CGFloat, dark: UInt32, darkAlpha: CGFloat) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark).withAlphaComponent(darkAlpha)
                : UIColor(hex: light).withAlphaComponent(lightAlpha)
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
