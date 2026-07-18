//
//  ChecklistEntryRow.swift
//  LastPlace
//
//  Whole row is the toggle target, matching the single-tap-target convention
//  used elsewhere (`RoomCard`, `SearchResultRow`) rather than a separate
//  checkbox button nested inside a tappable row.
//
//  Shows a thumbnail + location for linked entries (pulled live from the
//  linked `StoredItem`) and a location for unlinked entries when the user
//  bothered to type one — the point of the checklist is grabbing things fast
//  on the way out, so "where is it" matters as much as "what is it".
//

import SwiftUI

struct ChecklistEntryRow: View {
    let entry: ChecklistEntry
    let linkedItem: StoredItem?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(entry.isCompleted ? AppColor.accent : AppColor.textTertiary)
                    .accessibilityHidden(true)

                if let linkedItem {
                    thumbnail(for: linkedItem)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(AppFont.body(14.5))
                        .strikethrough(entry.isCompleted)
                        .foregroundStyle(entry.isCompleted ? AppColor.textTertiary : AppColor.textPrimary)
                        .lineLimit(2)

                    if let locationCaption {
                        Label(locationCaption, systemImage: linkedItem != nil ? "link" : "mappin.and.ellipse")
                            .font(AppFont.body(11.5))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(entry.isCompleted ? "Done" : "Not done")
        .accessibilityHint("Toggles done.")
    }

    private func thumbnail(for item: StoredItem) -> some View {
        AsyncStoredImage(path: item.imagePath, contentMode: .fill, placeholderSymbol: item.category.symbolName)
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    /// Linked entries always show the item's live location (falling back to
    /// its category if no location was ever set); unlinked entries show
    /// whatever the user typed, if anything.
    private var locationCaption: String? {
        if let linkedItem {
            return linkedItem.locationDescription.isEmpty
                ? linkedItem.category.displayName
                : linkedItem.locationDescription
        }
        guard let location = entry.locationDescription, !location.isEmpty else { return nil }
        return location
    }

    private var accessibilityLabel: String {
        guard let linkedItem else {
            guard let location = entry.locationDescription, !location.isEmpty else { return entry.title }
            return "\(entry.title), \(location)"
        }
        return "\(entry.title), linked to \(linkedItem.name)"
    }
}
