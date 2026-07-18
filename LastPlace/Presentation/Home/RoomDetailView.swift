//
//  RoomDetailView.swift
//  LastPlace
//

import SwiftUI

struct RoomDetailView: View {
    let coordinator: HomeCoordinator
    @State private var viewModel: RoomDetailViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(coordinator: HomeCoordinator, viewModel: RoomDetailViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: navigationTitle, onBack: { dismiss() }) {
                Menu {
                    menuContent
                } label: {
                    AppNavCircleIcon(systemName: "ellipsis")
                }
            }
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .confirmationDialog(
                "Delete this room?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete room", role: .destructive) {
                    Task {
                        let didDelete = await viewModel.deleteRoom()
                        if didDelete {
                            coordinator.popToRoot()
                            coordinator.refreshHome()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Items in this room and their photos will also be removed.")
            }
            .alert(
                viewModel.deletionError?.title ?? "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.deletionError != nil },
                    set: { if !$0 { viewModel.deletionError = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { viewModel.deletionError = nil }
                },
                message: { Text(viewModel.deletionError?.message ?? "") }
            )
    }

    private var navigationTitle: String {
        if case .loaded(let content) = viewModel.state { return content.room.name }
        return "Room"
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing here yet",
                message: "This room has no saved items.",
                symbolName: "shippingbox"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let content):
            loadedView(content)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if case .loaded(let content) = viewModel.state {
            Button {
                coordinator.push(.editRoom(roomID: content.room.id))
            } label: {
                Label("Edit room", systemImage: "pencil")
            }
            Button {
                coordinator.push(.scanRoom(roomID: content.room.id))
            } label: {
                Label("Scan room", systemImage: "camera.viewfinder")
            }
            Divider()
        }
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete room", systemImage: "trash")
        }
    }

    private func loadedView(_ content: RoomDetailContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(for: content.room)
                itemsSection(items: content.items, room: content.room)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func header(for room: Room) -> some View {
        HStack(spacing: 12) {
            Image(systemName: room.iconName)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 46, height: 46)
                .background(AppColor.surface, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(AppFont.heading(23))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Updated \(room.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(AppFont.body(12.5))
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
    }

    private func itemsSection(items: [StoredItem], room: Room) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Items in this room")

            if items.isEmpty {
                EmptyStateView(
                    title: "No items yet",
                    message: "Scan the room or add items manually to remember where they live.",
                    symbolName: "shippingbox",
                    primaryAction: EmptyStateAction(
                        title: "Scan room",
                        action: { coordinator.push(.scanRoom(roomID: room.id)) }
                    )
                )
                .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        HomeItemCard(item: item) {
                            coordinator.push(.itemDetail(itemID: item.id))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
