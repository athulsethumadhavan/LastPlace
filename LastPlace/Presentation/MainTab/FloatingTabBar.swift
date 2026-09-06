//
//  FloatingTabBar.swift
//  LastPlace
//
//  Replaces the native `TabView` chrome with the design mock's floating
//  "liquid glass" bar: a frosted pill anchored 20pt above the bottom edge
//  with 16pt side margins, the selected tab picked out with an accent-soft
//  background behind its icon/label. `MainTabView` keeps all four tabs
//  mounted in a `ZStack` and overlays this on top, rather than using
//  `TabView`'s own bottom bar — there's no supported way to reskin the
//  native bar to look like this, so it's fully custom.
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: AppMetrics.tabBarHeight)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.tabBarRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.tabBarRadius, style: .continuous)
                .fill(AppColor.glassBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.tabBarRadius, style: .continuous)
                .strokeBorder(AppColor.glassBorder, lineWidth: 1)
        )
        .appCardShadow()
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        // The mock wants a fixed 20pt gap from the true bottom edge, not
        // 20pt on top of whatever the home-indicator safe area already
        // reserves — without this the bar would float noticeably higher
        // than intended.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = tab == selection
        return Button {
            selection = tab
        } label: {
            VStack(spacing: isSelected ? 3 : 4) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                Text(tab.title)
                    .font(AppFont.body(10))
            }
            .foregroundStyle(isSelected ? AppColor.accent : AppColor.textTertiary)
            .padding(.vertical, isSelected ? 6 : 0)
            .padding(.horizontal, isSelected ? 14 : 0)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppColor.accentSoft : .clear)
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
