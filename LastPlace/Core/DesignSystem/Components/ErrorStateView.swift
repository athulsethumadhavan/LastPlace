//
//  ErrorStateView.swift
//  LastPlace
//

import SwiftUI

struct ErrorStateView: View {
    let error: UserFacingError
    let retryAction: (() -> Void)?

    init(error: UserFacingError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(error.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if error.isRetryable, let retryAction {
                Button("Try again", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(minHeight: 44)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorStateView(
        error: UserFacingError(message: "Couldn't reach the store."),
        retryAction: {}
    )
}
