//
//  SharedHomeDetailView.swift
//  LastPlace
//
//  Read-only. This shows exactly what was in the snapshot the last time
//  `FamilyFindView` fetched it — no live editing, no per-item detail
//  screen, since there's nothing further to look up beyond what the owner
//  chose to publish (name, location, last-seen date).
//

import SwiftUI

struct SharedHomeDetailView: View {
    let snapshot: SharedHomeSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppNavBar(title: snapshot.homeName, onBack: { dismiss() })
            List {
                Section {
                    row("Shared by", value: snapshot.ownerDisplayName)
                    row("Last updated", value: snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }

                ForEach(snapshot.rooms) { room in
                    Section {
                        if room.items.isEmpty {
                            Text("No items in this room.")
                                .font(AppFont.body(14))
                                .foregroundStyle(AppColor.textSecondary)
                                .listRowBackground(AppColor.background)
                        } else {
                            ForEach(room.items) { item in
                                itemRow(item)
                                    .listRowBackground(AppColor.background)
                            }
                        }
                    } header: {
                        Text(room.name)
                            .font(AppFont.heading(12, weight: .semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .kerning(0.5)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(AppColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text(value)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textSecondary)
        }
        .listRowBackground(AppColor.background)
    }

    private func itemRow(_ item: SharedItemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.name)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textPrimary)
                if item.isImportant {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }
            }
            Text(item.locationDescription)
                .font(AppFont.body(12))
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}
