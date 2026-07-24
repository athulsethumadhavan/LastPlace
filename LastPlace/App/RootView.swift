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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch coordinator.flow {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .onboarding:
                OnboardingView(onFinished: { coordinator.completeOnboarding() })
                    .transition(.opacity)

            case .authRequired:
                AuthView(authService: container.authService) { _ in
                    coordinator.completeSignIn()
                }
                .transition(.opacity)

            case .locked:
                LockView(coordinator: coordinator)
                    .transition(.opacity)

            case .main:
                MainTabView(container: container, onSignedOut: { coordinator.signOut() })
                    .transition(.opacity)

            case .failed(let reason):
                AppBootstrapErrorView(message: reason)
                    .transition(.opacity)
            }
        }
        .environment(\.imageStorage, container.imageStorage)
        .preferredColorScheme(container.appearanceSettings.mode.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: coordinator.flow)
        .task { await coordinator.start() }
        .task { await syncIfSignedIn() }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-arm the lock screen the moment the app leaves the
            // foreground, not just on relaunch — otherwise the app switcher
            // snapshot (and a quick foreground/background flip) would expose
            // content the lock setting is meant to hide.
            if newPhase == .background {
                coordinator.lockIfNeeded()
            }
            if newPhase == .active {
                Task { await syncIfSignedIn() }
            }
        }
    }

    /// General-purpose sync trigger for every launch/foreground where a
    /// session already exists -- `AppCoordinator.completeSignIn()` handles
    /// the one-off sync immediately after a fresh sign-in; this is what
    /// keeps things syncing on every subsequent open. Errors are swallowed
    /// deliberately: a failed background sync shouldn't interrupt whatever
    /// the person is doing, and every pending local change stays queued
    /// (`.pendingUpsert`/`.pendingDelete`) to retry on the next trigger
    /// regardless.
    private func syncIfSignedIn() async {
        guard let user = await container.authService.currentUser else { return }
        try? await container.syncEngine.sync(userID: user.id, imageStorage: container.imageStorage)
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
