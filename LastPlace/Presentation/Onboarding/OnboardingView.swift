//
//  OnboardingView.swift
//  LastPlace
//
//  Skeleton onboarding — the full three-page carousel with Continue / Skip /
//  Get Started buttons arrives in Phase 4. For now a single screen exists so
//  first-launch flow works end-to-end.
//

import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Welcome to LastPlace")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("Save where important items were last seen and find them again in seconds.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button(action: onFinished) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .accessibilityHint("Finishes onboarding and opens the main app.")
            }
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
