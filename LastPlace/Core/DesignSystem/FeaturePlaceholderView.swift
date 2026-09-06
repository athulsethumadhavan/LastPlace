//
//  FeaturePlaceholderView.swift
//  LastPlace
//
//  Shared placeholder for features not yet built out. Kept in one place so
//  every tab and pushed route has a consistent look before real content lands.
//

import SwiftUI

struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let symbolName: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: symbolName)
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    FeaturePlaceholderView(
        title: "Home",
        subtitle: "Rooms, recent items and important shortcuts.",
        symbolName: "house.fill"
    )
}
