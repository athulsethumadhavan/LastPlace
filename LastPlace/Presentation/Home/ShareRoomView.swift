//
//  ShareRoomView.swift
//  LastPlace
//
//  Owner-side sharing sheet, pushed from Room Detail's "Share room" menu
//  item. Invite a registered LastPlace user by email; see everyone this
//  room is currently shared with, pending or accepted; revoke access.
//

import SwiftUI

struct ShareRoomView: View {
    @State private var viewModel: ShareRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool

    init(viewModel: ShareRoomViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Share Room", onBack: { dismiss() })
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            ScrollView {
                inviteSection
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let shares):
            loadedView(shares)
        }
    }

    private func loadedView(_ shares: [OutgoingShareSummary]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                inviteSection
                sharesSection(shares)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Invite by email")
                    .font(AppFont.heading(12, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .kerning(0.5)
                TextField("", text: $viewModel.inviteEmail, prompt: Text("them@example.com").foregroundStyle(AppColor.textTertiary))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.invite() }
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
            }

            if let inviteError = viewModel.inviteError {
                Text(inviteError.message)
                    .font(AppFont.body(13.5))
                    .foregroundStyle(.red)
            }

            PrimaryButton("Send Invite", isEnabled: viewModel.canInvite, isLoading: viewModel.isInviting) {
                isEmailFocused = false
                viewModel.invite()
            }

            Text("They'll be able to see this room and its items, but not your checklists. Only people with a LastPlace account can be invited.")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func sharesSection(_ shares: [OutgoingShareSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Shared with")

            if shares.isEmpty {
                EmptyStateView(
                    title: "Not shared yet",
                    message: "Invite someone above to give them a read-only view of this room.",
                    symbolName: "person.2"
                )
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(shares) { summary in
                        shareRow(summary)
                    }
                }
            }
        }
    }

    private func shareRow(_ summary: OutgoingShareSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 22))
                .foregroundStyle(AppColor.accent)
                .frame(width: 36, height: 36)
                .background(AppColor.surface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.profile?.displayLabel ?? "LastPlace user")
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(summary.share.isAccepted ? "Accepted" : "Invite pending")
                    .font(AppFont.body(12))
                    .foregroundStyle(summary.share.isAccepted ? AppColor.accent : AppColor.textSecondary)
            }

            Spacer()

            Button {
                viewModel.revoke(summary.share.id)
            } label: {
                if viewModel.mutatingShareID == summary.share.id {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.mutatingShareID != nil)
        }
        .padding(12)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }
}

#Preview {
    ShareRoomView(
        viewModel: ShareRoomViewModel(
            roomID: UUID(),
            roomSharingService: MockRoomSharingService(),
            logger: OSAppLogger()
        )
    )
}
