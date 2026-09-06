//
//  ScanRootView.swift
//  LastPlace
//
//  Hosts the scan sub-flow. Switches between capture, review, and save-detection
//  screens driven by `ScanCoordinator.screen`. Owns the alerting for scan-level
//  errors so children don't have to duplicate the binding.
//

import SwiftUI

struct ScanRootView: View {
    let homeCoordinator: HomeCoordinator
    @State private var coordinator: ScanCoordinator

    init(homeCoordinator: HomeCoordinator, coordinator: ScanCoordinator) {
        self.homeCoordinator = homeCoordinator
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        Group {
            switch coordinator.screen {
            case .capture:
                ScanCaptureView(coordinator: coordinator, homeCoordinator: homeCoordinator)
            case .review:
                ScanReviewView(coordinator: coordinator, homeCoordinator: homeCoordinator)
            case .saveDetection(let captureID, let detection):
                ScanSaveItemView(
                    coordinator: coordinator,
                    homeCoordinator: homeCoordinator,
                    viewModel: coordinator.makeSaveItemViewModel(captureID: captureID, detection: detection)
                )
            }
        }
        .task { await coordinator.startSession() }
        .alert(
            coordinator.errorAlert?.title ?? "Something went wrong",
            isPresented: Binding(
                get: { coordinator.errorAlert != nil },
                set: { if !$0 { coordinator.errorAlert = nil } }
            ),
            actions: { Button("OK", role: .cancel) { coordinator.errorAlert = nil } },
            message: { Text(coordinator.errorAlert?.message ?? "") }
        )
    }
}
