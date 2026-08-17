//
//  SettingsView.swift
//  LastPlace
//

import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: SettingsCoordinator

    @State private var appearance: AppearanceViewModel
    @State private var account: AccountViewModel
    @State private var showingDeleteConfirmation = false

    init(coordinator: SettingsCoordinator) {
        self.coordinator = coordinator
        _appearance = State(initialValue: coordinator.makeAppearanceViewModel())
        _account = State(initialValue: coordinator.makeAccountViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    accountHeader
                        .padding(.bottom, 22)

                    sectionLabel("General")
                    settingsCard {
                        SettingsRow(title: "Privacy", symbol: "hand.raised") {
                            coordinator.push(.privacy)
                        }
                        SettingsRow(title: "Permissions", symbol: "checkmark.shield") {
                            coordinator.push(.permissions)
                        }
                        appearanceRow
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

                    sectionLabel("Sharing")
                    settingsCard {
                        SettingsRow(title: "Shared Rooms", symbol: "person.2") {
                            coordinator.push(.sharedRooms)
                        }
                        SettingsRow(title: "Gifts", symbol: "gift", showsDivider: false) {
                            coordinator.push(.gifts)
                        }
                    }
                    .padding(.bottom, 22)

                    sectionLabel("Account")
                    settingsCard {
                        SettingsActionRow(
                            title: "Sign Out",
                            symbol: "rectangle.portrait.and.arrow.right",
                            isLoading: account.isLoading
                        ) {
                            account.signOut()
                        }
                        SettingsActionRow(
                            title: "Delete Account",
                            symbol: "trash",
                            role: .destructive,
                            showsDivider: false,
                            isLoading: false
                        ) {
                            showingDeleteConfirmation = true
                        }
                        .disabled(account.isLoading)
                    }
                    .padding(.bottom, 22)

                    Text("Version \(Bundle.appVersionString)")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .padding(.top, 8)
                .scrollIndicators(.hidden)
            }
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SettingsRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                account.deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and its data. This can't be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { account.errorMessage != nil },
                set: { if !$0 { account.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) { account.errorMessage = nil } },
            message: { Text(account.errorMessage ?? "") }
        )
    }

    /// Replaces the pushed Account screen, which held nothing but an email
    /// and two buttons -- not enough to justify a navigation step. Showing
    /// who you're signed in as at the top of Settings is also just more
    /// useful there than one level down.
    private var accountHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(AppColor.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.user?.fullName ?? "Signed in")
                    .font(AppFont.heading(16))
                    .foregroundStyle(AppColor.textPrimary)
                if let email = account.user?.email {
                    Text(email)
                        .font(AppFont.body(13))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
        .appCardShadow()
    }

    /// A `Menu` rather than a pushed screen: three mutually-exclusive
    /// options with no explanation needed is exactly what a picker is for,
    /// and the old screen made changing theme a three-tap round trip.
    /// Showing the current value inline also means you can read the setting
    /// without opening anything.
    private var appearanceRow: some View {
        Menu {
            Picker("Appearance", selection: $appearance.mode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                }
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.accent)
                        .frame(width: 18)
                    Text("Appearance")
                        .font(AppFont.body(15))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text(appearance.mode.displayName)
                        .font(AppFont.body(14))
                        .foregroundStyle(AppColor.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)

                Rectangle()
                    .fill(AppColor.divider)
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
        }
        .buttonStyle(.plain)
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

/// Sibling to `SettingsRow` for rows that *do* something rather than
/// navigate somewhere. Deliberately no chevron -- that would promise a
/// screen that isn't coming -- and a spinner in its place while working, so
/// sign-out doesn't look inert on a slow network.
private struct SettingsActionRow: View {
    let title: String
    let symbol: String
    var role: ButtonRole?
    var showsDivider: Bool = true
    let isLoading: Bool
    let action: () -> Void

    private var tint: Color {
        role == .destructive ? .red : AppColor.accent
    }

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 18)
                    Text(title)
                        .font(AppFont.body(15))
                        .foregroundStyle(role == .destructive ? Color.red : AppColor.textPrimary)
                    Spacer()
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
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
