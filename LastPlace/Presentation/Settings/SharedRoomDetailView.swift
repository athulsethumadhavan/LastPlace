//
//  SharedRoomDetailView.swift
//  LastPlace
//
//  A room shared with you: the room and its items, live from the owner's
//  account. No edit/scan/delete/share actions and no checklists — those stay
//  with the owner. Items are no longer read-only, though: tapping one pushes
//  `SharedItemDetailView`, where the location can be updated.
//

import SwiftUI

struct SharedRoomDetailView: View {
    let navigator: any SharedRoomNavigator
    @State private var viewModel: SharedRoomDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(navigator: any SharedRoomNavigator, viewModel: SharedRoomDetailViewModel) {
        self.navigator = navigator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: navigationTitle, onBack: { dismiss() })
            content
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        // Reloads on return rather than only on first appearance: a viewer
        // who just updated an item's location pops back to this grid, and
        // without this the card would still show the old location.
        .onAppear {
            if case .loaded = viewModel.state {
                Task { await viewModel.load() }
            }
        }
        .refreshable { await viewModel.load() }
    }

    private var navigationTitle: String {
        if case .loaded(let content) = viewModel.state { return content.room.name }
        return "Shared Room"
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

    private func loadedView(_ content: SharedRoomDetailContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(for: content)
                itemsSection(items: content.items)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func header(for content: SharedRoomDetailContent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: content.room.iconName)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 46, height: 46)
                .background(AppColor.surface, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.room.name)
                    .font(AppFont.heading(23))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Shared by \(content.ownerProfile?.displayLabel ?? "a LastPlace user")")
                    .font(AppFont.body(12.5))
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
    }

    private func itemsSection(items: [StoredItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Items in this room")

            if items.isEmpty {
                EmptyStateView(
                    title: "No items yet",
                    message: "The owner hasn't added any items to this room.",
                    symbolName: "shippingbox"
                )
                .padding(.vertical, 8)
                // No "add item" action here even though viewers can now
                // write: they can record where an existing thing is, not
                // introduce new things into someone else's inventory.
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        SharedItemCard(item: item, loadImage: viewModel.loadImageData) {
                            navigator.pushSharedItemDetail(
                                itemID: item.id,
                                roomID: viewModel.roomID,
                                ownerID: viewModel.ownerID
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
