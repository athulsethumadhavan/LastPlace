//
//  ForgotPasswordView.swift
//  LastPlace
//
//  Presented as a sheet from AuthView's "Forgot password?" link.
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var viewModel: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool

    init(authService: AuthService, prefillEmail: String = "") {
        _viewModel = State(initialValue: ForgotPasswordViewModel(authService: authService, prefillEmail: prefillEmail))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.didSend {
                    confirmation
                } else {
                    form
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .background(AppColor.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .onAppear { isEmailFocused = true }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reset your password")
                    .font(AppFont.heading(24))
                    .foregroundStyle(AppColor.textPrimary)
                Text("We'll email you a link to set a new password.")
                    .font(AppFont.body(14.5))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("EMAIL")
                    .font(AppFont.heading(12, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .kerning(0.5)
                TextField("you@example.com", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.submit() }
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.body(13.5))
                    .foregroundStyle(.red)
            }

            PrimaryButton("Send Reset Link", isEnabled: viewModel.canSubmit, isLoading: viewModel.isLoading) {
                isEmailFocused = false
                viewModel.submit()
            }
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppColor.accent)
            Text("Check your email")
                .font(AppFont.heading(24))
                .foregroundStyle(AppColor.textPrimary)
            Text("If an account exists for \(viewModel.email), a reset link is on its way.")
                .font(AppFont.body(14.5))
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

#Preview {
    ForgotPasswordView(authService: MockAuthService())
}
