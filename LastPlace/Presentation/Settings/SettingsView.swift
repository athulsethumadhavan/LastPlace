//
//  SettingsView.swift
//  LastPlace
//

import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: SettingsCoordinator

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("General")
                    settingsCard {
                        SettingsRow(title: "Privacy", symbol: "hand.raised") {
                            coordinator.push(.privacy)
                        }
                        SettingsRow(title: "Permissions", symbol: "checkmark.shield") {
                            coordinator.push(.permissions)
                        }
                        SettingsRow(title: "Appearance", symbol: "paintbrush") {
                            coordinator.push(.appearance)
                        }
                        SettingsRow(title: "Security", symbol: "lock.shield", showsDivider: false) {
                            coordinator.push(.security)
                        }
                    }
                    .padding(.bottom, 22)

                    sectionLabel("Data")
                    settingsCard {
                        SettingsRow(title: "Data Management", symbol: "externaldrive", showsDivider: false) {
                            coordinator.push(.dataManagement)
                        }
                    }
                    .padding(.bottom, 22)

                    sectionLabel("Account")
                    settingsCard {
                        SettingsRow(title: "Account", symbol: "person.crop.circle", showsDivider: false) {
                            coordinator.push(.account)
                        }
                    }
                    .padding(.bottom, 22)

                    Text("Version \(Bundle.appVersionString)")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SettingsRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var header: some View {
        Text("Settings")
            .font(AppFont.heading(30))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppFont.heading(12, weight: .semibold))
            .foregroundStyle(AppColor.textSecondary)
            .kerning(0.5)
            .padding(.bottom, 8)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
            .appCardShadow()
    }
}

private struct SettingsRow: View {
    let title: String
    let symbol: String
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.accent)
                        .frame(width: 18)
                    Text(title)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)

                if showsDivider {
                    Rectangle()
                        .fill(AppColor.divider)
                        .frame(height: 1)
                        .padding(.leading, 14)
                }
            }
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
