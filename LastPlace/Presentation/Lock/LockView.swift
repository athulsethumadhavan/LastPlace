//
//  LockView.swift
//  LastPlace
//
//  Shown whenever `AppCoordinator.flow == .locked` — at launch and whenever
//  the app returns from the background with the lock setting on. Talks to
//  `AppCoordinator` directly rather than through a dedicated view model,
//  same call as `PrivacyView`: there's no state here beyond the in-flight
//  authentication attempt, which is purely local UI state.
//

import SwiftUI

struct LockView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var isAuthenticating = false
    @State private var didFail = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: coordinator.biometryKind.symbolName)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("LastPlace is locked")
                    .font(.title3.weight(.semibold))
                if didFail {
                    Text("Authentication failed. Try again.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await attemptUnlock() }
            } label: {
                Text("Unlock with \(coordinator.biometryKind.displayName)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task { await attemptUnlock() }
    }

    private func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        let success = await coordinator.unlock()
        didFail = !success
        isAuthenticating = false
    }
}
