//
//  RootView.swift
//  LastPlace
//
//  Reads `AppCoordinator.flow` and mounts the matching root scene. Individual
//  scenes are built through the container so nothing here constructs its own
//  dependencies. Injects `ImageStorageService` into the SwiftUI environment so
//  `AsyncStoredImage` works anywhere below.
//

import SwiftUI

struct RootView: View {
    let container: AppDependencyContainer
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.flow {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .onboarding:
                OnboardingView(onFinished: { coordinator.completeOnboarding() })
                    .transition(.opacity)

            case .main:
                MainTabView(container: container)
                    .transition(.opacity)

            case .failed(let reason):
                AppBootstrapErrorView(message: reason)
                    .transition(.opacity)
            }
        }
        .environment(\.imageStorage, container.imageStorage)
        .animation(.easeInOut(duration: 0.25), value: coordinator.flow)
        .task { await coordinator.start() }
    }
}

struct AppBootstrapErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Couldn't start LastPlace")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
