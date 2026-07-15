//
//  AppearanceView.swift
//  LastPlace
//

import SwiftUI

struct AppearanceView: View {
    @Bindable var viewModel: AppearanceViewModel

    var body: some View {
        List {
            Section {
                Picker("Appearance", selection: $viewModel.mode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("Choose how LastPlace looks, or match your device's system setting.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
