//
//  EmptyStateView.swift
//  LastPlace
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbolName: String
    let primaryAction: EmptyStateAction?

    init(
        title: String,
        message: String,
        symbolName: String,
        primaryAction: EmptyStateAction? = nil
    ) {
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.primaryAction = primaryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            if let primaryAction {
                Button(action: primaryAction.action) {
                    Text(primaryAction.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateAction {
    let title: String
    let action: () -> Void
}

#Preview {
    EmptyStateView(
        title: "No rooms yet",
        message: "Add your first room to start saving where important items live.",
        symbolName: "house.badge.exclamationmark",
        primaryAction: EmptyStateAction(title: "Create a room", action: {})
    )
}
