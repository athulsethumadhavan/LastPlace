//
//  HomeView.swift
//  LastPlace
//

import SwiftUI

struct HomeView: View {
    let coordinator: HomeCoordinator
    @State private var viewModel: HomeViewModel

    init(coordinator: HomeCoordinator, viewModel: HomeViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: HomeRoute.self) { route in
            coordinator.destination(for: route)
                .toolbar(.hidden, for: .tabBar)
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.refresh() }
        .overlay(alignment: .bottomTrailing) {
            if showsFloatingAddRoomButton {
                addRoomButton
            }
        }
    }

    private var header: some View {
        Text(title)
            .font(AppFont.heading(30))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 20)
            // Safe area already clears the status bar/notch here; only a
            // small supplemental gap is needed on top of that.
            .padding(.top, 8)
            .padding(.bottom, 14)
    }

    /// Hidden while the empty state is showing — that screen already has its
    /// own prominent "Create a room" CTA, so a second "add" affordance would
    /// just be clutter.
    private var showsFloatingAddRoomButton: Bool {
        if case .loaded(let content) = viewModel.state { return !content.isFullyEmpty }
        return false
    }

    private var addRoomButton: some View {
        Button {
            coordinator.push(.createRoom)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AppColor.accent, in: Circle())
                .appCardShadow()
        }
        .accessibilityLabel("Add a room")
        .padding(.trailing, 20)
        // Native `TabView` already reserves safe-area space for its own tab
        // bar, so this only needs a small visual gap above it — no manual
        // clearance math like the old floating-bar version needed.
        .padding(.bottom, 16)
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { return content.home.name }
        return "LastPlace"
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Getting your home ready…")
        case .empty:
            emptyStateView
        case .failed(let error):
            ErrorStateView(error: error, retryAction: { Task { await viewModel.refresh() } })
        case .loaded(let content):
            if content.isFullyEmpty {
                emptyStateView
            } else {
                dashboard(for: content)
            }
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            title: "No rooms yet",
            message: "Add your first room to start saving where important items live.",
            symbolName: "house.badge.exclamationmark",
            primaryAction: EmptyStateAction(
                title: "Create a room",
                action: { coordinator.push(.createRoom) }
            )
        )
        .padding(.top, 32)
    }

    private func dashboard(for content: HomeDashboardContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if !content.importantItems.isEmpty {
                    itemsSection(title: "Important", items: content.importantItems)
                }
                if !content.recentItems.isEmpty {
                    itemsSection(title: "Recently updated", items: content.recentItems)
                }
                roomsSection(content.rooms)
            }
            .padding(.top, 16)
            // Native `TabView` already reserves safe-area space for its own
            // bar; this just needs enough room for the floating add-room
            // button to not sit on top of the last row once scrolled down.
            .padding(.bottom, 100)
        }
    }

    private func itemsSection(title: String, items: [StoredItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        HomeItemCard(item: item) {
                            coordinator.push(.itemDetail(itemID: item.id))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            // `ScrollView` clips its content to its own frame by default, so
            // even with the extra top/bottom padding above, `AppCard`'s
            // shadow (which blurs outward in every direction, not just
            // downward) was still getting a hard edge cut into it wherever
            // that padding wasn't generous enough. This disables that
            // clipping outright so the shadow can render past the
            // scrollable content's bounds without being cut off.
            .scrollClipDisabled()
        }
    }

    private func roomsSection(_ rooms: [Room]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Rooms",
                actionTitle: rooms.isEmpty ? nil : "Add",
                action: rooms.isEmpty ? nil : { coordinator.push(.createRoom) }
            )
            .padding(.horizontal, 20)

            if rooms.isEmpty {
                EmptyStateView(
                    title: "No rooms yet",
                    message: "Add a room to organize where things live.",
                    symbolName: "house",
                    primaryAction: EmptyStateAction(
                        title: "Create a room",
                        action: { coordinator.push(.createRoom) }
                    )
                )
                .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(rooms) { room in
                        RoomCard(room: room) {
                            coordinator.push(.roomDetail(roomID: room.id))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
