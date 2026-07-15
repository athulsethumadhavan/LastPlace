//
//  PrivacyView.swift
//  LastPlace
//
//  Purely informational — no state to load or mutate, so this skips a
//  dedicated view model unlike the other Settings destinations.
//

import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
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
            } footer: {
                Text("See Permissions to check or change what LastPlace can access, and Data Management to review or delete everything that's saved.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
