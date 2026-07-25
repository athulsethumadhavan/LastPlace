//
//  GiftItemView.swift
//  LastPlace
//
//  Owner-side gifting sheet, pushed from Item Detail's "Gift item" menu
//  action. Enter the recipient's email and send; the item stays in your
//  own inventory until they accept it.
//

import SwiftUI

struct GiftItemView: View {
    @State private var viewModel: GiftItemViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool

    init(viewModel: GiftItemViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Gift Item", onBack: { dismiss() })
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .onAppear { isEmailFocused = true }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing to show",
                message: "This item couldn't be loaded.",
                symbolName: "gift"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let item):
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let sentGift = viewModel.sentGift {
                        confirmation(item: item, gift: sentGift)
                    } else {
                        form(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
    }

    private func form(item: StoredItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            iconBadge

            VStack(alignment: .leading, spacing: 8) {
                Text("Gift \u{201C}\(item.name)\u{201D}")
                    .font(AppFont.heading(24))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Sends a one-time copy to another LastPlace account. It stays in your own inventory until they accept it into one of their rooms.")
                    .font(AppFont.body(13.5))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RECIPIENT EMAIL")
                    .font(AppFont.heading(12, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .kerning(0.5)
                TextField("", text: $viewModel.recipientEmail, prompt: Text("them@example.com").foregroundStyle(AppColor.textTertiary))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.send() }
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
            }

            if let sendError = viewModel.sendError {
                Text(sendError.message)
                    .font(AppFont.body(13.5))
                    .foregroundStyle(.red)
            }

            PrimaryButton("Send Gift", symbolName: "gift", isEnabled: viewModel.canSend, isLoading: viewModel.isSending) {
                isEmailFocused = false
                viewModel.send()
            }

            Text("Only people with a LastPlace account can receive a gift right now.")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func confirmation(item: StoredItem, gift: ItemGift) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            iconBadge
            Text("Gift sent")
                .font(AppFont.heading(24))
                .foregroundStyle(AppColor.textPrimary)
            Text("\u{201C}\(item.name)\u{201D} is waiting for them to accept it. You'll keep it in your own inventory until then.")
                .font(AppFont.body(14.5))
                .foregroundStyle(AppColor.textSecondary)
            Button("Done") { dismiss() }
                .buttonStyle(.plain)
                .font(AppFont.heading(14))
                .foregroundStyle(AppColor.accent)
                .padding(.top, 4)
        }
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppColor.accentSoft)
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "gift.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(AppColor.accent)
            }
    }
}
