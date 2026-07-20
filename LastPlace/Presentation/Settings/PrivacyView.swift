//
//  PrivacyView.swift
//  LastPlace
//
//  Purely informational — no state to load or mutate, so this skips a
//  dedicated view model unlike the other Settings destinations.
//

import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Privacy", onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyRow(
                        symbol: "cpu",
                        title: "Recognition happens on-device",
                        detail: "Room scans are processed with Apple's Vision framework directly on your phone. Nothing is uploaded to identify what's in a photo."
                    )
                    privacyRow(
                        symbol: "iphone",
                        title: "Rooms, items, and checklists stay on this device",
                        detail: "Everything you save is stored locally on your phone, with no cloud backup yet. Deleting the app or losing this device means losing that data too, unless you've backed up the whole device another way."
                    )
                    privacyRow(
                        symbol: "camera",
                        title: "Camera access is scoped to scanning",
                        detail: "The camera only turns on while you're actively capturing a room. It isn't used in the background."
                    )
                    privacyRow(
                        symbol: "chart.bar.xaxis",
                        title: "No analytics or tracking",
                        detail: "LastPlace doesn't collect usage analytics or share information with advertisers."
                    )
                    Text("See Permissions to check or change what LastPlace can access, and Data Management to review or delete everything that's saved.")
                        .font(AppFont.body(12.5))
                        .foregroundStyle(AppColor.textTertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func privacyRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(detail)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
