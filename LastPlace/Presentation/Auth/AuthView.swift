//
//  AuthView.swift
//  LastPlace
//
//  Combined sign-in / sign-up screen (a segmented toggle switches between the
//  two, matching the "one screen, two modes" pattern most auth flows use).
//  Not yet wired into app launch -- see the roadmap note on sequencing this
//  after Phase 2's data-layer migration, so users aren't gated behind an
//  account before there's anything server-side for that account to hold.
//

import AuthenticationServices
import SwiftUI

struct AuthView: View {
    let authService: AuthService
    @State private var viewModel: AuthViewModel
    @State private var showingForgotPassword = false
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private enum Field {
        case email, password
    }

    init(authService: AuthService, onAuthenticated: @escaping @MainActor (AuthUser) -> Void) {
        self.authService = authService
        _viewModel = State(initialValue: AuthViewModel(authService: authService, onAuthenticated: onAuthenticated))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                fieldGroup(title: "Email") {
                    TextField("you@example.com", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldGroup(title: "Password") {
                    SecureField("At least 6 characters", text: $viewModel.password)
                        .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { viewModel.submit() }
                }

                if viewModel.mode == .signIn {
                    Button("Forgot password?") {
                        focusedField = nil
                        showingForgotPassword = true
                    }
                    .font(AppFont.body(13.5))
                    .foregroundStyle(AppColor.accent)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.body(13.5))
                        .foregroundStyle(.red)
                }

                PrimaryButton(
                    viewModel.mode.primaryButtonTitle,
                    isEnabled: viewModel.canSubmit,
                    isLoading: viewModel.isLoading
                ) {
                    focusedField = nil
                    viewModel.submit()
                }

                dividerRow

                SignInWithAppleButton(
                    .continue,
                    onRequest: { viewModel.prepareAppleRequest($0) },
                    onCompletion: { viewModel.handleAppleCompletion($0) }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                googleButton

                toggleRow
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .background(AppColor.background)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView(authService: authService, prefillEmail: viewModel.email)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.mode.headline)
                .font(AppFont.heading(28))
                .foregroundStyle(AppColor.textPrimary)
            Text("LastPlace keeps your rooms and items in sync.")
                .font(AppFont.body(14.5))
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(AppFont.heading(12, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)
            content()
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColor.divider).frame(height: 1)
            Text("or")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textSecondary)
            Rectangle().fill(AppColor.divider).frame(height: 1)
        }
    }

    private var googleButton: some View {
        Button {
            viewModel.signInWithGoogle()
        } label: {
            HStack(spacing: 8) {
                Text("G")
                    .font(AppFont.heading(16, weight: .bold))
                    .foregroundStyle(AppColor.accent)
                Text("Continue with Google")
                    .font(AppFont.heading(15))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColor.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.5 : 1)
        .accessibilityLabel("Continue with Google")
    }

    private var toggleRow: some View {
        HStack(spacing: 4) {
            Text(viewModel.mode.toggleQuestion)
                .font(AppFont.body(14))
                .foregroundStyle(AppColor.textSecondary)
            Button(viewModel.mode.toggleActionTitle) {
                viewModel.toggleMode()
            }
            .font(AppFont.heading(14))
            .foregroundStyle(AppColor.accent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }
}

#Preview {
    AuthView(authService: MockAuthService()) { _ in }
}
