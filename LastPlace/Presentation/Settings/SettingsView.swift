//
//  SettingsView.swift
//  LastPlace
//

import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: SettingsCoordinator

    var body: some View {
        List {
            Section("General") {
                SettingsRow(title: "Privacy", symbol: "hand.raised") {
                    coordinator.push(.privacy)
                }
                SettingsRow(title: "Permissions", symbol: "checkmark.shield") {
                    coordinator.push(.permissions)
                }
                SettingsRow(title: "Appearance", symbol: "paintbrush") {
                    coordinator.push(.appearance)
                }
            }
            Section("Data") {
                SettingsRow(title: "Data Management", symbol: "externaldrive") {
                    coordinator.push(.dataManagement)
                }
            }
            Section {
                LabeledContent("Version", value: Bundle.appVersionString)
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.footnote.weight(.semibold))
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private extension Bundle {
    static var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
