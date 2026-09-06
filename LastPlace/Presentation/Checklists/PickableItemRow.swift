//
//  PickableItemRow.swift
//  LastPlace
//
//  Row used in the checklist "Add item" picker. Similar layout to
//  `SearchResultRow` but the trailing affordance is an add/added indicator
//  rather than a chevron, since tapping adds the item in place instead of
//  navigating away.
//

import SwiftUI

struct PickableItemRow: View {
    let item: StoredItem
    let isAdded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncStoredImage(path: item.imagePath, contentMode: .fill, placeholderSymbol: item.category.symbolName)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isAdded ? Color.green : Color.accentColor)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)")
        .accessibilityHint(isAdded ? "Already added." : "Adds this item to the checklist.")
    }
}
