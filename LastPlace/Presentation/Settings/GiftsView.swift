//
//  GiftsView.swift
//  LastPlace
//
//  Reached from Settings → Gifts. Three sections: gifts waiting for you to
//  accept (pick a destination room) or decline, gifts you've already
//  resolved, and gifts you've sent (cancel while still pending).
//

import SwiftUI

struct GiftsView: View {
    @State private var viewModel: GiftsViewModel
    @State private var acceptingGift: IncomingGiftSummary?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: GiftsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Gifts", onBack: { dismiss() })
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .sheet(item: $acceptingGift) { summary in
            RoomPickerSheet(
                title: "Add \u{201C}\(summary.gift.itemName)\u{201D} to which room?",
                fetchRooms: viewModel.fetchRoomsForAccept,
                onSelect: { room in
                    viewModel.accept(summary.gift.id, intoRoomID: room.id)
                    acceptingGift = nil
                }
            )
        }
        .alert(
            viewModel.actionError?.title ?? "Something went wrong",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { if !$0 { viewModel.actionError = nil } }
            ),
            actions: { Button("OK", role: .cancel) { viewModel.actionError = nil } },
            message: { Text(viewModel.actionError?.message ?? "") }
        )
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
            title: "No gifts yet",
            message: "Gift an item to another LastPlace account from its detail screen, or check back here when someone gifts one to you.",
            symbolName: "gift"
        )
    }

    private var loadedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.pendingIncoming.isEmpty && viewModel.resolvedIncoming.isEmpty && viewModel.outgoing.isEmpty {
                    emptyState.padding(.top, 8)
                } else {
                    if !viewModel.pendingIncoming.isEmpty { pendingIncomingSection }
                    if !viewModel.outgoing.isEmpty { outgoingSection }
                    if !viewModel.resolvedIncoming.isEmpty { resolvedIncomingSection }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    private var pendingIncomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Waiting for you")
            VStack(spacing: 10) {
                ForEach(viewModel.pendingIncoming) { summary in
                    pendingIncomingRow(summary)
                }
            }
        }
    }

    private func pendingIncomingRow(_ summary: IncomingGiftSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: summary.gift.itemCategory.symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 40, height: 40)
                    .background(AppColor.surface, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.gift.itemName)
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("From \(summary.senderProfile?.displayLabel ?? "a LastPlace user")")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.decline(summary.gift.id)
                } label: {
                    Text("Decline")
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    acceptingGift = summary
                } label: {
                    if viewModel.mutatingGiftID == summary.gift.id {
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
            .disabled(viewModel.mutatingGiftID != nil)
        }
        .padding(12)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Sent by you")
            VStack(spacing: 10) {
                ForEach(viewModel.outgoing) { summary in
                    outgoingRow(summary)
                }
            }
        }
    }

    private func outgoingRow(_ summary: OutgoingGiftSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: summary.gift.itemCategory.symbolName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 40, height: 40)
                .background(AppColor.surface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.gift.itemName)
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("To \(summary.recipientProfile?.displayLabel ?? "a LastPlace user") \u{2022} \(statusLabel(summary.gift.status))")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            if summary.gift.status == .pending {
                Button {
                    viewModel.cancel(summary.gift.id)
                } label: {
                    if viewModel.mutatingGiftID == summary.gift.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.mutatingGiftID != nil)
            }
        }
        .padding(12)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }

    private var resolvedIncomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Past gifts to you")
            VStack(spacing: 10) {
                ForEach(viewModel.resolvedIncoming) { summary in
                    HStack(spacing: 12) {
                        Image(systemName: summary.gift.itemCategory.symbolName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(AppColor.surface, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.gift.itemName)
                                .font(AppFont.body(13.5, weight: .semibold))
                                .foregroundStyle(AppColor.textPrimary)
                            Text("From \(summary.senderProfile?.displayLabel ?? "a LastPlace user") \u{2022} \(statusLabel(summary.gift.status))")
                                .font(AppFont.body(11.5))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
                }
            }
        }
    }

    private func statusLabel(_ status: ItemGiftStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        }
    }
}

/// Destination-room picker for accepting a gift — the same "default home →
/// its rooms" lookup `CreateRoomHost` (Home tab) uses, just reused inline
/// here as a sheet instead of a pushed screen.
private struct RoomPickerSheet: View {
    let title: String
    let fetchRooms: () async throws -> [Room]
    let onSelect: (Room) -> Void

    @State private var rooms: [Room] = []
    @State private var error: UserFacingError?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if let error {
                    ErrorStateView(error: error) { Task { await load() } }
                } else if rooms.isEmpty {
                    EmptyStateView(
                        title: "No rooms yet",
                        message: "Create a room first, then come back to accept this gift.",
                        symbolName: "house"
                    )
                } else {
                    List(rooms) { room in
                        Button {
                            onSelect(room)
                        } label: {
                            Label(room.name, systemImage: room.iconName)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            rooms = try await fetchRooms()
        } catch {
            self.error = UserFacingError.from(error)
        }
        isLoading = false
    }
}
