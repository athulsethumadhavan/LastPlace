//
//  AppearanceView.swift
//  LastPlace
//

import SwiftUI

struct AppearanceView: View {
    @Bindable var viewModel: AppearanceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Appearance", onBack: { dismiss() })
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
                    .tint(AppColor.accent)
                    .listRowBackground(AppColor.background)
                } footer: {
                    Text("Choose how LastPlace looks, or match your device's system setting.")
                        .font(AppFont.body(12.5))
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}
