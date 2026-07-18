//
//  FamilyFindView.swift
//  LastPlace
//
//  "Family Find" — a read-only shared snapshot, not collaborative editing.
//  See `CloudKitHomeSharingService`'s file-level doc comment for why.
//

import SwiftUI

struct FamilyFindView: View {
    let coordinator: SettingsCoordinator
    @State private var viewModel: FamilyFindViewModel
    @State private var isConfirmingStopSharing = false

    init(coordinator: SettingsCoordinator, viewModel: FamilyFindViewModel) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: viewModel)
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: "Family Find", onBack: { dismiss() })
            List {
                myHomeSection
                sharedWithMeSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = viewModel.myHomeState { await viewModel.loadMyHome() }
            if case .idle = viewModel.sharedHomesState { await viewModel.loadSharedHomes() }
        }
        .refreshable {
            await viewModel.loadMyHome()
            await viewModel.loadSharedHomes()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.pendingShare != nil },
            set: { if !$0 { viewModel.pendingShare = nil } }
        )) {
            // `CKShare` isn't `Identifiable`, so this uses `isPresented`
            // rather than `.sheet(item:)`; `pendingShare` is only ever set
            // right before presenting, so the force-unwrap here is safe.
            if let share = viewModel.pendingShare {
                CloudSharingViewRepresentable(
                    share: share,
                    container: viewModel.sharingContainer,
                    itemTitle: myHomeTitle
                )
            }
        }
        .confirmationDialog(
            "Stop sharing your home?",
            isPresented: $isConfirmingStopSharing,
            titleVisibility: .visible
        ) {
            Button("Stop Sharing", role: .destructive) {
                Task { await viewModel.stopSharingMyHome() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Family members you've invited will lose access to this home's shared snapshot.")
        }
        .alert(
            viewModel.error?.title ?? "Something went wrong",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            actions: { Button("OK", role: .cancel) { viewModel.error = nil } },
            message: { Text(viewModel.error?.message ?? "") }
        )
    }

    private var myHomeTitle: String {
        if case .loaded(let home) = viewModel.myHomeState { return "\(home.name) — LastPlace" }
        return "My Home — LastPlace"
    }

    // MARK: - My Home

    @ViewBuilder
    private var myHomeSection: some View {
        Section {
            switch viewModel.myHomeState {
            case .idle, .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(AppColor.background)
            case .empty:
                Text("No home set up yet.")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textSecondary)
                    .listRowBackground(AppColor.background)
            case .failed(let error):
                Text(error.message)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textSecondary)
                    .listRowBackground(AppColor.background)
            case .loaded(let home):
                Button {
                    Task { await viewModel.shareMyHome() }
                } label: {
                    HStack {
                        Text(viewModel.isMyHomeShared ? "Manage Sharing" : "Share \(home.name)")
                            .font(AppFont.body(15))
                        Spacer()
                        if viewModel.isPreparingShare {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isPreparingShare)
                .listRowBackground(AppColor.background)

                if viewModel.isMyHomeShared {
                    Button("Stop Sharing", role: .destructive) {
                        isConfirmingStopSharing = true
                    }
                    .font(AppFont.body(15))
                    .listRowBackground(AppColor.background)
                }
            }
        } header: {
            Text("My Home")
                .font(AppFont.heading(12, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)
        } footer: {
            Text("Family members you invite get a read-only, on-demand snapshot of your rooms and item locations — they can look things up, not edit them. Tap \u{201C}Manage Sharing\u{201D} to invite more people, remove someone, or refresh what's shared.")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textTertiary)
        }
    }

    // MARK: - Shared With Me

    @ViewBuilder
    private var sharedWithMeSection: some View {
        Section {
            switch viewModel.sharedHomesState {
            case .idle, .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(AppColor.background)
            case .empty:
                Text("No one has shared a home with you yet.")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textSecondary)
                    .listRowBackground(AppColor.background)
            case .failed(let error):
                Text(error.message)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textSecondary)
                    .listRowBackground(AppColor.background)
            case .loaded(let snapshots):
                ForEach(snapshots) { snapshot in
                    NavigationLink {
                        SharedHomeDetailView(snapshot: snapshot)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.homeName)
                                .font(AppFont.body(15))
                                .foregroundStyle(AppColor.textPrimary)
                            Text("Shared by \(snapshot.ownerDisplayName) · \(snapshot.itemCount) items")
                                .font(AppFont.body(12))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .listRowBackground(AppColor.background)
                }
            }
        } header: {
            Text("Shared With Me")
                .font(AppFont.heading(12, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .kerning(0.5)
        } footer: {
            Text("Pull to refresh to get the latest from each home.")
                .font(AppFont.body(12.5))
                .foregroundStyle(AppColor.textTertiary)
        }
    }
}
