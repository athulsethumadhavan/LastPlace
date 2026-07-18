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
                skipRow

                TabView(selection: Binding(
                    get: { viewModel.currentIndex },
                    set: { viewModel.currentIndex = $0 }
                )) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots
                    .padding(.bottom, 24)

                controls
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
            .background(AppColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var skipRow: some View {
        HStack {
            Spacer()
            if !viewModel.isLastPage {
                Button("Skip", action: viewModel.skip)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.currentIndex ? AppColor.accent : AppColor.divider)
                    .frame(width: index == viewModel.currentIndex ? 20 : 6, height: 3)
            }
        }
    }

    private var controls: some View {
        PrimaryButton(viewModel.primaryButtonTitle, symbolName: viewModel.isLastPage ? nil : "arrow.right", action: {
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
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColor.surface)
                    .frame(width: 200, height: 200)
                Image(systemName: page.symbolName)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(AppColor.accent)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(AppFont.heading(28))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.subtitle)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(onFinished: {})
}
