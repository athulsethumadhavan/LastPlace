//
//  SharedRoomsView.swift
//  LastPlace
//
//  Recipient-side sharing screen, reached from Settings → Shared Rooms.
//  Two sections: pending invites (accept/decline) and rooms already shared
//  with you (open read-only, or leave via long-press).
//

import SwiftUI

struct SharedRoomsView: View {
    let coordinator: SettingsCoordinator
    @State private var viewModel: SharedRoomsViewModel
    @State private var decliningShareID: UUID?
    @State private var leavingShareID: UUID?
    @Environment(\.dismiss) private var dismiss

    init(coordinator: SettingsCoordinator, viewModel: SharedRoomsViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Shared Rooms", onBack: { dismiss() })
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .alert(
            viewModel.actionError?.title ?? "Something went wrong",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { if !$0 { viewModel.actionError = nil } }
            ),
            actions: { Button("OK", role: .cancel) { viewModel.actionError = nil } },
            message: { Text(viewModel.actionError?.message ?? "") }
        )
        .confirmationDialog(
            "Decline this invite?",
            isPresented: Binding(
                get: { decliningShareID != nil },
                set: { if !$0 { decliningShareID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) {
                if let id = decliningShareID { viewModel.decline(id) }
                decliningShareID = nil
            }
        } message: {
            Text("You won't see this room unless the owner shares it with you again.")
        }
        .confirmationDialog(
            "Leave this shared room?",
            isPresented: Binding(
                get: { leavingShareID != nil },
                set: { if !$0 { leavingShareID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                if let id = leavingShareID { viewModel.decline(id) }
                leavingShareID = nil
            }
        } message: {
            Text("You'll lose access until the owner shares it with you again.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            emptyState
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded:
            loadedView
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No shared rooms",
            message: "When someone shares a room with you, it'll show up here.",
            symbolName: "person.2"
        )
    }

    private var loadedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.pending.isEmpty && viewModel.accepted.isEmpty {
                    emptyState.padding(.top, 8)
                } else {
                    if !viewModel.pending.isEmpty { pendingSection }
                    if !viewModel.accepted.isEmpty { acceptedSection }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Pending invites")
            VStack(spacing: 10) {
                ForEach(viewModel.pending) { summary in
                    pendingRow(summary)
                }
            }
        }
    }

    private func pendingRow(_ summary: IncomingShareSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: summary.room?.iconName ?? "house")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 40, height: 40)
                    .background(AppColor.surface, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.room?.name ?? "A room")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("From \(summary.ownerProfile?.displayLabel ?? "a LastPlace user")")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    decliningShareID = summary.share.id
                } label: {
                    Text("Decline")
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.accept(summary.share.id)
                } label: {
                    if viewModel.mutatingShareID == summary.share.id {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    } else {
                        Text("Accept")
                            .font(AppFont.body(13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(AppColor.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .buttonStyle(.plain)
            }
            .disabled(viewModel.mutatingShareID != nil)
        }
        .padding(12)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }

    private var acceptedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Shared with you")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(viewModel.accepted) { summary in
                    if let room = summary.room {
                        RoomCard(room: room) {
                            coordinator.push(.sharedRoomDetail(roomID: room.id, ownerID: summary.share.ownerID))
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                leavingShareID = summary.share.id
                            } label: {
                                Label("Leave shared room", systemImage: "person.crop.circle.badge.minus")
                            }
                        }
                    }
                }
            }
        }
    }
}
