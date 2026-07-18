//
//  SecurityView.swift
//  LastPlace
//

import SwiftUI

struct SecurityView: View {
    @Bindable var viewModel: SecurityViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Security", onBack: { dismiss() })
            List {
                if viewModel.biometryKind.isAvailable {
                    Section {
                        Toggle("Require \(viewModel.biometryKind.displayName)", isOn: $viewModel.isEnabled)
                            .tint(AppColor.accent)
                            .foregroundStyle(AppColor.textPrimary)
                            .listRowBackground(AppColor.background)
                    } footer: {
                        Text("When on, LastPlace locks itself as soon as you leave the app and asks for \(viewModel.biometryKind.displayName) before showing your rooms and items again.")
                            .font(AppFont.body(12.5))
                            .foregroundStyle(AppColor.textTertiary)
                    }
                } else {
                    Section {
                        Label("Not available on this device", systemImage: "lock.slash")
                            .font(AppFont.body(15))
                            .foregroundStyle(AppColor.textSecondary)
                            .listRowBackground(AppColor.background)
                    } footer: {
                        Text("This device doesn't have Face ID or Touch ID set up, so app lock isn't available.")
                            .font(AppFont.body(12.5))
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}
