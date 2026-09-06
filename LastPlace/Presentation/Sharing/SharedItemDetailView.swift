//
//  SharedItemDetailView.swift
//  LastPlace
//
//  Full detail screen for an item in a room shared with you -- pushed on the
//  navigation stack like the owner-side `ItemDetailView`, not presented as a
//  sheet. A sheet was right while this was read-only; now that a viewer can
//  record where something is, it needs to behave like a real destination
//  (deep-linkable, back-navigable, able to push further).
//
//  Deliberately not `ItemDetailView` itself: that screen reads local
//  SwiftData through repositories and offers delete / gift / toggle-importance,
//  none of which apply to an item this account doesn't own.
//

import SwiftUI

struct SharedItemDetailView: View {
    @State private var viewModel: SharedItemDetailViewModel
    @State private var isEditingLocation = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SharedItemDetailViewModel) {
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
        .sheet(isPresented: $isEditingLocation) {
            if case .loaded(let content) = viewModel.state {
                UpdateSharedItemLocationSheet(
                    itemName: content.item.name,
                    currentLocation: content.item.locationDescription,
                    isSaving: viewModel.isSaving
                ) { newLocation in
                    await viewModel.updateLocation(to: newLocation)
                }
            }
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

    private var navigationTitle: String {
        if case .loaded(let content) = viewModel.state { return content.item.name }
        return "Shared Item"
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
        case .loaded(let content):
            loadedView(content)
        }
    }

    private func loadedView(_ content: SharedItemDetailContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AsyncRemoteImage(
                    path: content.item.imagePath,
                    contentMode: .fill,
                    placeholderSymbol: content.item.category.symbolName,
                    load: viewModel.loadImageData
                )
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))

                locationCard(content)
                detailsSection(content)
                historySection(content)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    /// Location gets its own card at the top, above the static details,
    /// because it's both the thing people came to read and the only thing
    /// they can change.
    private func locationCard(_ content: SharedItemDetailContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE IT IS")
                .font(AppFont.heading(11.5, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)

            Text(content.item.locationDescription.isEmpty
                 ? "No location recorded yet"
                 : content.item.locationDescription)
                .font(AppFont.body(16))
                .foregroundStyle(content.item.locationDescription.isEmpty
                                 ? AppColor.textSecondary
                                 : AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Last seen \(content.item.lastSeenAt.formatted(.relative(presentation: .named)))")
                .font(AppFont.body(12))
                .foregroundStyle(AppColor.textSecondary)

            Button {
                isEditingLocation = true
            } label: {
                Label("Update location", systemImage: "mappin.and.ellipse")
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(AppColor.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }

    private func detailsSection(_ content: SharedItemDetailContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Details")

            detailRow(label: "Category", value: content.item.category.displayName)
            if let notes = content.item.notes, !notes.isEmpty {
                detailRow(label: "Notes", value: notes)
            }
            detailRow(
                label: "Room owner",
                value: content.ownerProfile?.displayLabel ?? "a LastPlace user"
            )

            // Says plainly what this account can and can't do, rather than
            // leaving someone to discover the missing actions by looking for
            // them. The restriction is enforced in Postgres either way.
            Text("Only the room's owner can rename, delete, or share this item.")
                .font(AppFont.body(12))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func historySection(_ content: SharedItemDetailContent) -> some View {
        if !content.history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Location history")

                VStack(spacing: 0) {
                    ForEach(Array(content.history.enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry)
                        if index < content.history.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
            }
        }
    }

    private func historyRow(_ entry: SharedItemHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.locationDescription.isEmpty ? "Location cleared" : entry.locationDescription)
                .font(AppFont.body(14, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(attribution(for: entry))
                .font(AppFont.body(11.5))
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    /// "You" rather than the viewer's own name -- reading your own name back
    /// at you in a list you're looking at is oddly impersonal. Falls back to
    /// time-only when the entry predates attribution, instead of inventing a
    /// culprit.
    private func attribution(for entry: SharedItemHistoryEntry) -> String {
        let when = entry.capturedAt.formatted(.relative(presentation: .named))
        if entry.wasSetBy(viewModel.currentUserID) {
            return "You · \(when)"
        }
        if let name = entry.setBy?.displayLabel {
            return "\(name) · \(when)"
        }
        return when
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
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Text-only, by design. A photo taken here would be uploaded to this
/// account's Storage folder, while every reader -- the owner's device, other
/// viewers -- resolves an item's image path against the *owner's* folder. It
/// would be written somewhere nobody looks. Supporting it properly means
/// recording whose folder each image lives in and teaching every read path
/// to consult that, which is a separate change.
private struct UpdateSharedItemLocationSheet: View {
    let itemName: String
    let currentLocation: String
    let isSaving: Bool
    /// Returns true when the save landed, which dismisses the sheet.
    let onSave: (String) async -> Bool

    @State private var text: String = ""
    @State private var hasSeeded = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Where is \(itemName) now?")
                    .font(AppFont.heading(19))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField(
                    "e.g. top drawer of the hallway cabinet",
                    text: $text,
                    axis: .vertical
                )
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.plain)
                .font(AppFont.body(15))
                .padding(12)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($isFocused)
                .submitLabel(.done)

                Text("\(text.count)/\(StoredItem.locationMaxLength)")
                    .font(AppFont.body(11.5))
                    .foregroundStyle(
                        text.count > StoredItem.locationMaxLength ? Color.red : AppColor.textSecondary
                    )

                Spacer()
            }
            .padding(20)
            .background(AppColor.background)
            .navigationTitle("Update location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Save") {
                            Task { if await onSave(text) { dismiss() } }
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                    }
                }
            }
        }
        .onAppear {
            // Seeded once, not on every re-render: `isSaving` flipping would
            // otherwise reset whatever the person had typed.
            if !hasSeeded {
                text = currentLocation
                hasSeeded = true
            }
            isFocused = true
        }
    }

    /// Blocks a no-op save as well as an over-long one -- submitting the
    /// value that's already there would still write a history entry and fire
    /// a push to everyone in the room.
    private var canSave: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed.count <= StoredItem.locationMaxLength
            && trimmed != currentLocation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
