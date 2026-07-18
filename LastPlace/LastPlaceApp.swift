//
//  LastPlaceApp.swift
//  LastPlace
//
//  Entry point + bootstrap of the composition root. The container is built
//  lazily inside `.task` so init failures (e.g. corrupt SwiftData store) surface
//  as an in-app error screen instead of a launch crash.
//

import SwiftUI

@main
struct LastPlaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap.state {
                case .loading:
                    SplashView()
                case .ready(let container, let coordinator):
                    RootView(container: container, coordinator: coordinator)
                case .failed(let message):
                    AppBootstrapErrorView(message: message)
                }
            }
            .task { await bootstrap.startIfNeeded() }
        }
    }
}

@MainActor
@Observable
private final class AppBootstrap {
    enum State {
        case loading
        case ready(AppDependencyContainer, AppCoordinator)
        case failed(String)
    }

    private(set) var state: State = .loading

    func startIfNeeded() async {
        if case .ready = state { return }
        if case .failed = state { return }

        do {
            let container = try AppDependencyContainer.makeDefault()
            let coordinator = AppCoordinator(container: container)
            state = .ready(container, coordinator)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
