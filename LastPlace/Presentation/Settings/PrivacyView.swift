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
                        symbol: "icloud",
                        title: "Synced privately through your iCloud",
                        detail: "Rooms, items, and checklists sync through your private iCloud account so they're available on your other devices and backed up if you lose this one. LastPlace has no server of its own — Apple's CloudKit is the only place this data travels, and only your iCloud account can read it."
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
