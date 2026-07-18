//
//  ItemDetailView.swift
//  LastPlace
//
//  Shows an item's photo, metadata, location description, notes, and snapshot
//  history. Toolbar exposes toggle-importance, update-location, and delete
//  actions. Depends on `ItemDetailNavigator` so it can be hosted from either
//  the Home or Search tab.
//

import SwiftUI

struct ItemDetailView: View {
    let navigator: ItemDetailNavigator
    @State private var viewModel: ItemDetailViewModel
    @State private var isConfirmingDelete = false

    init(navigator: ItemDetailNavigator, viewModel: ItemDetailViewModel) {
        self.navigator = navigator
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: navigationTitle, onBack: { navigator.popTop() }) {
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
                "Delete this item?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete item", role: .destructive) {
                    Task {
                        if await viewModel.deleteItem() {
                            navigator.popTop()
                            navigator.refreshAfterItemMutation()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The item and its snapshot history will be removed.")
            }
            .alert(
                viewModel.mutationError?.title ?? "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.mutationError != nil },
                    set: { if !$0 { viewModel.mutationError = nil } }
                ),
                actions: { Button("OK", role: .cancel) { viewModel.mutationError = nil } },
                message: { Text(viewModel.mutationError?.message ?? "") }
            )
    }

    private var navigationTitle: String {
        if case .loaded(let content) = viewModel.state { return content.item.name }
        return "Item"
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
                symbolName: "shippingbox"
            )
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let detail):
            loadedView(detail)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if case .loaded(let detail) = viewModel.state {
            Button {
                Task { await viewModel.toggleImportance() }
                navigator.refreshAfterItemMutation()
            } label: {
                Label(
                    detail.item.isImportant ? "Unmark important" : "Mark as important",
                    systemImage: detail.item.isImportant ? "star.slash" : "star"
                )
            }
            Button {
                navigator.pushUpdateItemLocation(itemID: detail.item.id)
            } label: {
                Label("Update location", systemImage: "mappin.and.ellipse")
            }
            Divider()
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("Delete item", systemImage: "trash")
            }
        }
    }

    private func loadedView(_ detail: ItemDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage(detail.item)
                header(detail)
                locationCard(detail)
                notesCard(detail.item)
                snapshotsSection(detail.snapshots)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    private func heroImage(_ item: StoredItem) -> some View {
        AsyncStoredImage(
            path: item.imagePath,
            contentMode: .fill,
            placeholderSymbol: item.category.symbolName
        )
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func header(_ detail: ItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: detail.item.category.symbolName)
                    .foregroundStyle(AppColor.accent)
                Text(detail.item.category.displayName)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
                if detail.item.isImportant {
                    Label("Important", systemImage: "star.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Marked as important")
                }
                Spacer()
            }

            Text(detail.item.name)
                .font(AppFont.heading(26))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("In \(detail.room.name)")
                .font(AppFont.body(13))
                .foregroundStyle(AppColor.textSecondary)

            Text("Updated \(detail.item.updatedAt.formatted(.relative(presentation: .named)))")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textTertiary)
        }
    }

    private func locationCard(_ detail: ItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Location")
            VStack(alignment: .leading, spacing: 6) {
                if detail.item.locationDescription.isEmpty {
                    Text("No location set")
                        .font(AppFont.body(15))
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    Text(detail.item.locationDescription)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppColor.textPrimary)
                }
                Text("Last seen \(detail.item.lastSeenAt.formatted(.relative(presentation: .named)))")
                    .font(AppFont.body(12.5))
                    .foregroundStyle(AppColor.textTertiary)
                Button {
                    navigator.pushUpdateItemLocation(itemID: detail.item.id)
                } label: {
                    Label("Update location", systemImage: "mappin.and.ellipse")
                        .font(AppFont.body(13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.accent)
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private func notesCard(_ item: StoredItem) -> some View {
        if let notes = item.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Notes")
                Text(notes)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func snapshotsSection(_ snapshots: [ItemSnapshot]) -> some View {
        if !snapshots.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Snapshot history")
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(snapshots) { snapshot in
                        snapshotCard(snapshot)
                    }
                }
            }
        }
    }

    private func snapshotCard(_ snapshot: ItemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncStoredImage(
                path: snapshot.imagePath,
                contentMode: .fill,
                placeholderSymbol: "photo"
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if !snapshot.locationDescription.isEmpty {
                    Text(snapshot.locationDescription)
                        .font(AppFont.body(12.5, weight: .medium))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                }
                Text(snapshot.capturedAt.formatted(.relative(presentation: .named)))
                    .font(AppFont.body(11))
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
        .padding(8)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppMetrics.plateRadius - 2, style: .continuous))
    }
}
