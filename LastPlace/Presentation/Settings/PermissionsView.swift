//
//  PermissionsView.swift
//  LastPlace
//

import SwiftUI
import UIKit

struct PermissionsView: View {
    @State private var viewModel = PermissionsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                LabeledContent("Camera") {
                    Text(viewModel.cameraStatus.displayName)
                        .foregroundStyle(viewModel.cameraStatus.isGranted ? Color.secondary : Color.orange)
                }
                if !viewModel.cameraStatus.isGranted {
                    Button("Open Settings") { openSystemSettings() }
                }
            } footer: {
                Text("LastPlace uses the camera only while you're actively scanning a room, to detect and photograph items. Nothing is recorded in the background.")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            // Catches the user granting/denying access from the system
            // Settings screen and coming back without leaving this view.
            if newPhase == .active { viewModel.refresh() }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
