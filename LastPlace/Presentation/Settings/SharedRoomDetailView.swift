//
//  SharedRoomDetailView.swift
//  LastPlace
//
//  Read-only mirror of `RoomDetailView` for a room shared with you: no
//  edit/scan/delete/share actions, no checklists — just the room and its
//  items, live from the owner's account.
//

import SwiftUI

struct SharedRoomDetailView: View {
    @State private var viewModel: SharedRoomDetailViewModel
    @State private var selectedItem: StoredItem?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SharedRoomDetailViewModel) {
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
        .refreshable { await viewModel.load() }
        .sheet(item: $selectedItem) { item in
            SharedItemDetailSheet(item: item, loadImage: viewModel.loadImageData)
        }
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
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        SharedItemCard(item: item, loadImage: viewModel.loadImageData) {
                            selectedItem = item
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

/// A lightweight read-only detail sheet — this app has no shared-item
/// editing in this pass, so there's no need for the full `ItemDetailView`
/// (which assumes local ownership: edit, delete, toggle-importance,
/// location history).
private struct SharedItemDetailSheet: View {
    let item: StoredItem
    let loadImage: (String) async throws -> Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppNavBar(title: item.name, onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncRemoteImage(
                        path: item.imagePath,
                        contentMode: .fill,
                        placeholderSymbol: item.category.symbolName,
                        load: loadImage
                    )
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))

                    detailRow(label: "Category", value: item.category.displayName)
                    detailRow(label: "Location", value: item.locationDescription.isEmpty ? "Not set" : item.locationDescription)
                    detailRow(label: "Last seen", value: item.lastSeenAt.formatted(.relative(presentation: .named)))
                    if let notes = item.notes, !notes.isEmpty {
                        detailRow(label: "Notes", value: notes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(AppFont.heading(11.5, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)
            Text(value)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textPrimary)
        }
    }
}
