//
//  AuthView.swift
//  LastPlace
//
//  Combined sign-in / sign-up screen (a segmented toggle switches between the
//  two, matching the "one screen, two modes" pattern most auth flows use).
//  Shown by `RootView` for `AppFlow.authRequired` -- a mandatory, non-
//  dismissible gate at launch whenever there's no active Supabase session.
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
        case fullName, email, password, confirmPassword
    }

    init(authService: AuthService, onAuthenticated: @escaping @MainActor (AuthUser) -> Void) {
        self.authService = authService
        _viewModel = State(initialValue: AuthViewModel(authService: authService, onAuthenticated: onAuthenticated))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if viewModel.mode == .signUp {
                    fieldGroup(title: "Full name") {
                        TextField("", text: $viewModel.fullName, prompt: placeholder("Jordan Lee"))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .fullName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                    }
                }

                fieldGroup(title: "Email") {
                    TextField("", text: $viewModel.email, prompt: placeholder("you@example.com"))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldGroup(title: "Password") {
                    SecureField("", text: $viewModel.password, prompt: placeholder("At least 6 characters"))
                        .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(viewModel.mode == .signUp ? .next : .go)
                        .onSubmit {
                            if viewModel.mode == .signUp {
                                focusedField = .confirmPassword
                            } else {
                                viewModel.submit()
                            }
                        }
                }

                if viewModel.mode == .signIn {
                    HStack {
                        Spacer()
                        Button("Forgot password?") {
                            focusedField = nil
                            showingForgotPassword = true
                        }
                        .font(AppFont.body(12.5))
                        .foregroundStyle(AppColor.accent)
                    }
                }

                if viewModel.mode == .signUp {
                    fieldGroup(title: "Confirm password") {
                        SecureField("", text: $viewModel.confirmPassword, prompt: placeholder("At least 6 characters"))
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.go)
                            .onSubmit { viewModel.submit() }
                    }
                    if viewModel.passwordMismatch {
                        Text("Passwords don't match.")
                            .font(AppFont.body(12.5))
                            .foregroundStyle(.red)
                    }
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

                googleButton

                SignInWithAppleButton(
                    viewModel.mode == .signUp ? .signUp : .signIn,
                    onRequest: { viewModel.prepareAppleRequest($0) },
                    onCompletion: { viewModel.handleAppleCompletion($0) }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.pendingVerificationEmail != nil },
            set: { isPresented in
                if !isPresented { viewModel.pendingVerificationEmail = nil }
            }
        )) {
            OTPView(email: viewModel.pendingVerificationEmail ?? "", authService: authService) { user in
                viewModel.completeVerification(user)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image("AuthAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .appCardShadow()

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.mode.headline)
                    .font(AppFont.heading(27))
                    .foregroundStyle(AppColor.textPrimary)
                Text(viewModel.mode.subheadline)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppColor.textSecondary)
            }
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

    /// `TextField`/`SecureField`'s plain-string placeholder initializer
    /// renders in the environment's tint color, which falls back to system
    /// blue here since this project's `AccentColor` asset is unset -- the
    /// `prompt:` initializer is the only way to give the placeholder its own
    /// explicit color instead of inheriting that.
    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundStyle(AppColor.textTertiary)
    }

    private var dividerRow: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColor.divider).frame(height: 1)
            Text("or continue with")
                .font(AppFont.body(12)).lineLimit(1).fixedSize()
                .foregroundStyle(AppColor.textTertiary)
            Rectangle().fill(AppColor.divider).frame(height: 1)
        }
    }

    /// Custom rather than the native `GIDSignInButton`: Google's own control
    /// only ever renders its fixed "Sign in with Google" copy at its own
    /// size/shadow, which reads as a mismatched floating card next to the
    /// flat Apple button beside it. This still uses Google's real four-color
    /// "G" logomark (`GoogleLogo` asset, rendered from Google's own SVG
    /// artwork -- not a plain glyph) so it stays on-brand; only the
    /// container chrome (size, border, copy) is custom, matching the rest of
    /// this screen. Tapping it still goes through the same
    /// `viewModel.signInWithGoogle()` -> `GIDSignIn` flow as before.
    private var googleButton: some View {
        Button {
            viewModel.signInWithGoogle()
        } label: {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
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
