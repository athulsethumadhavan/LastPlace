//
//  AccountView.swift
//  LastPlace
//
//  Sign-out and account-deletion (App Store Review Guideline 5.1.1(v)).
//  Reached via Settings' "Account" row (`SettingsRoute.account`).
//

import SwiftUI

struct AccountView: View {
    @State private var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    init(authService: AuthService, onSignedOut: @escaping @MainActor () -> Void) {
        _viewModel = State(initialValue: AccountViewModel(authService: authService, onSignedOut: onSignedOut))
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Account") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let email = viewModel.user?.email {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SIGNED IN AS")
                                .font(AppFont.heading(12, weight: .semibold))
                                .foregroundStyle(AppColor.textSecondary)
                                .kerning(0.5)
                            Text(email)
                                .font(AppFont.body(15))
                                .foregroundStyle(AppColor.textPrimary)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppFont.body(13.5))
                            .foregroundStyle(.red)
                    }

                    PrimaryButton("Sign Out", isLoading: viewModel.isLoading) {
                        viewModel.signOut()
                    }

                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Delete Account")
                            .font(AppFont.heading(15))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                viewModel.deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and its data. This can't be undone.")
        }
    }
}

#Preview {
    AccountView(authService: MockAuthService(user: AuthUser(id: UUID(), email: "preview@example.com"))) {}
}
