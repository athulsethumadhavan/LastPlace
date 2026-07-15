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
        content
            .navigationTitle(title)
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
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel("Add a room")
        .padding(.trailing, 20)
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
            LazyVStack(alignment: .leading, spacing: 24) {
                if !content.importantItems.isEmpty {
                    itemsSection(title: "Important", items: content.importantItems)
                }
                if !content.recentItems.isEmpty {
                    itemsSection(title: "Recently updated", items: content.recentItems)
                }
                roomsSection(content.rooms)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            // Extra bottom clearance so the floating add-room button doesn't
            // sit on top of the last row once scrolled to the bottom.
            .padding(.bottom, 96)
        }
    }

    private func itemsSection(title: String, items: [StoredItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        HomeItemCard(item: item) {
                            coordinator.push(.itemDetail(itemID: item.id))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func roomsSection(_ rooms: [Room]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Rooms",
                actionTitle: rooms.isEmpty ? nil : "Add",
                action: rooms.isEmpty ? nil : { coordinator.push(.createRoom) }
            )

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
            }
        }
    }
}
