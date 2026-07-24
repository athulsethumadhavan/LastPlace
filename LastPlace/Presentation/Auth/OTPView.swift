//
//  OTPView.swift
//  LastPlace
//
//  Matches the design mock's "05 · OTP verification" screen. Presented by
//  `AuthView` as a full-screen cover whenever `AuthViewModel.pendingVerificationEmail`
//  is set -- right after Sign Up (no session yet) or when a Sign In attempt
//  reveals the account was never verified.
//

import SwiftUI

struct OTPView: View {
    @State private var viewModel: OTPViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCodeFocused: Bool

    init(email: String, authService: AuthService, onVerified: @escaping @MainActor (AuthUser) -> Void) {
        _viewModel = State(initialValue: OTPViewModel(email: email, authService: authService, onVerified: onVerified))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppNavCircleButton(systemName: "chevron.left") { dismiss() }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    iconBadge

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter verification code")
                            .font(AppFont.heading(27))
                            .foregroundStyle(AppColor.textPrimary)
                        (
                            Text("We sent a 6-digit code to ")
                                + Text(viewModel.email).fontWeight(.semibold).foregroundStyle(AppColor.textPrimary)
                        )
                        .font(AppFont.body(14))
                        .foregroundStyle(AppColor.textSecondary)
                    }

                    codeBoxes

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppFont.body(13.5))
                            .foregroundStyle(.red)
                    }

                    PrimaryButton("Verify", isEnabled: viewModel.canSubmit, isLoading: viewModel.isLoading) {
                        isCodeFocused = false
                        viewModel.submit()
                    }

                    resendRow
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background)
        .onAppear { isCodeFocused = true }
        .onChange(of: viewModel.code) { _, newValue in
            if newValue.count == 6 { viewModel.submit() }
        }
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppColor.accentSoft)
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(AppColor.accent)
            }
    }

    /// A single hidden `TextField` captures keyboard input -- including
    /// iOS's QuickType one-time-code suggestion from Mail via
    /// `.textContentType(.oneTimeCode)` -- while these six boxes render the
    /// visual result. There's no built-in multi-box code field in SwiftUI,
    /// so this is the standard pattern for one.
    private var codeBoxes: some View {
        let digits = Array(viewModel.code)
        return ZStack {
            TextField("", text: $viewModel.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isCodeFocused)
                .opacity(0.01)

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    Text(index < digits.count ? String(digits[index]) : "")
                        .font(AppFont.heading(22))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous)
                                .strokeBorder(index == digits.count ? AppColor.accent : Color.clear, lineWidth: 1.5)
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { isCodeFocused = true }
    }

    private var resendRow: some View {
        HStack(spacing: 4) {
            Text("Didn't get it?")
                .font(AppFont.body(13))
                .foregroundStyle(AppColor.textSecondary)
            Button(viewModel.resendCooldown > 0 ? "Resend in 0:\(String(format: "%02d", viewModel.resendCooldown))" : "Resend") {
                viewModel.resend()
            }
            .disabled(viewModel.resendCooldown > 0)
            .font(AppFont.heading(13))
            .foregroundStyle(viewModel.resendCooldown > 0 ? AppColor.textTertiary : AppColor.accent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    OTPView(email: "jordan@example.com", authService: MockAuthService()) { _ in }
}
