//
//  OnboardingView.swift
//  LastPlace
//

import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(onFinished: @escaping @MainActor () -> Void) {
        _viewModel = State(initialValue: OnboardingViewModel(onFinished: onFinished))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: Binding(
                    get: { viewModel.currentIndex },
                    set: { viewModel.currentIndex = $0 }
                )) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                controls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar {
                if !viewModel.isLastPage {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip", action: viewModel.skip)
                    }
                }
            }
        }
    }

    private var controls: some View {
        PrimaryButton(viewModel.primaryButtonTitle, action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.advance()
            }
        })
        .accessibilityHint(viewModel.isLastPage ? "Finishes onboarding and opens the main app." : "Goes to the next onboarding step.")
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.symbolName)
                .font(.system(size: 76, weight: .regular))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.top, 8)
    }
}

#Preview("Onboarding") {
    OnboardingView(onFinished: {})
}
