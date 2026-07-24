//
//  ForgotPasswordView.swift
//  LastPlace
//
//  Presented as a sheet from AuthView's "Forgot password?" link. Matches the
//  design mock's "04 · Forgot password" screen: a plain back-chevron circle
//  (no title bar, no system "Close" text) since the mock's pushed-screen
//  chrome here is just the bare button, plus an accent-tinted icon badge
//  above the heading.
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
        VStack(alignment: .leading, spacing: 0) {
            AppNavCircleButton(systemName: "chevron.left") { dismiss() }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.didSend {
                        confirmation
                    } else {
                        form
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background)
        .onAppear { isEmailFocused = true }
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppColor.accentSoft)
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(AppColor.accent)
            }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge

            VStack(alignment: .leading, spacing: 8) {
                Text("Forgot password?")
                    .font(AppFont.heading(27))
                    .foregroundStyle(AppColor.textPrimary)
                Text("No worries — enter the email on your account and we'll send you a reset link.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("EMAIL")
                    .font(AppFont.heading(12, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .kerning(0.5)
                TextField("", text: $viewModel.email, prompt: Text("you@example.com").foregroundStyle(AppColor.textTertiary))
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

            HStack(spacing: 4) {
                Text("Remembered it?")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
                Button("Sign in") { dismiss() }
                    .font(AppFont.heading(13))
                    .foregroundStyle(AppColor.accent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 12) {
            iconBadge
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
