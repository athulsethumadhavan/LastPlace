//
//  PermissionsView.swift
//  LastPlace
//

import SwiftUI
import UIKit

struct PermissionsView: View {
    @State private var viewModel = PermissionsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Permissions", onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Camera")
                                .font(AppFont.body(15))
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            Text(viewModel.cameraStatus.displayName)
                                .font(AppFont.body(14))
                                .foregroundStyle(viewModel.cameraStatus.isGranted ? AppColor.textSecondary : Color.orange)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)

                        if !viewModel.cameraStatus.isGranted {
                            Rectangle().fill(AppColor.divider).frame(height: 1).padding(.leading, 14)
                            Button("Open Settings") { openSystemSettings() }
                                .font(AppFont.body(15))
                                .foregroundStyle(AppColor.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 46)
                        }
                    }
                    .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
                    .appCardShadow()

                    Text("LastPlace uses the camera only while you're actively scanning a room, to detect and photograph items. Nothing is recorded in the background.")
                        .font(AppFont.body(12.5))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
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
