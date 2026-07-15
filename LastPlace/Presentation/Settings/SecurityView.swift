//
//  SecurityView.swift
//  LastPlace
//

import SwiftUI

struct SecurityView: View {
    @Bindable var viewModel: SecurityViewModel

    var body: some View {
        List {
            if viewModel.biometryKind.isAvailable {
                Section {
                    Toggle("Require \(viewModel.biometryKind.displayName)", isOn: $viewModel.isEnabled)
                } footer: {
                    Text("When on, LastPlace locks itself as soon as you leave the app and asks for \(viewModel.biometryKind.displayName) before showing your rooms and items again.")
                }
            } else {
                Section {
                    Label("Not available on this device", systemImage: "lock.slash")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("This device doesn't have Face ID or Touch ID set up, so app lock isn't available.")
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}
