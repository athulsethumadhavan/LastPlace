//
//  AppNavBar.swift
//  LastPlace
//
//  Custom nav chrome matching the design mock's pushed-screen header: a
//  circular bordered back button, a centered serif title, and a circular
//  bordered trailing button (often a `Menu` trigger). The system nav bar
//  can't be reskinned to look like this (title font/size, circular button
//  borders aren't reachable via `.navigationTitle` styling), so screens
//  using this hide the system bar entirely with
//  `.toolbar(.hidden, for: .navigationBar)` and place this at the top of
//  their own layout instead. Back navigation still goes through
//  `@Environment(\.dismiss)`, which works the same on a pushed
//  `NavigationStack` screen as it does on a sheet.
//

import SwiftUI

/// The circular bordered icon used for both the back button and trailing
/// actions — exposed on its own (not just wrapped in a `Button`) so it can
/// also serve as a `Menu`'s `label`, which needs a plain `View`.
struct AppNavCircleIcon: View {
    let systemName: String
    var filled: Bool = false
    /// Renders fully transparent and removes it from accessibility, without
    /// changing this view's type — needed so the no-trailing-action
    /// `AppNavBar` convenience initializer (which requires the closure to
    /// return exactly `AppNavCircleIcon`, not `some View`) can produce an
    /// invisible placeholder by setting a property instead of chaining a
    /// modifier like `.hidden()`.
    var isHidden: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.white : AppColor.textPrimary)
            .frame(width: 32, height: 32)
            .background(filled ? AppColor.accent : Color.clear, in: Circle())
            .overlay(
                Circle().strokeBorder(filled ? Color.clear : AppColor.divider, lineWidth: 1)
            )
            .opacity(isHidden ? 0 : 1)
            .accessibilityHidden(isHidden)
    }
}

struct AppNavCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppNavCircleIcon(systemName: systemName)
        }
        .buttonStyle(.plain)
    }
}

struct AppNavBar<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            AppNavCircleButton(systemName: "chevron.left", action: onBack)
            Spacer()
            Text(title)
                .font(AppFont.heading(17))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        // The mock's "56px from the top" is measured from the very top edge
        // of the device frame, i.e. it already includes the status bar/
        // notch. This `VStack` isn't ignoring the safe area, so that
        // clearance is already applied automatically — a small supplemental
        // gap is all that's needed on top of it.
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(AppColor.background)
    }
}

extension AppNavBar where Trailing == AppNavCircleIcon {
    /// For screens with no trailing action — keeps the title visually
    /// centered by mirroring the back button's footprint with an
    /// invisible placeholder rather than leaving the trailing side empty.
    init(title: String, onBack: @escaping () -> Void) {
        self.title = title
        self.onBack = onBack
        self.trailing = { AppNavCircleIcon(systemName: "chevron.left", isHidden: true) }
    }
}
