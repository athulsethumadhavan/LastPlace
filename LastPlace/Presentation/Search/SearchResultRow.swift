//
//  SearchResultRow.swift
//  LastPlace
//
//  List-style item row for the Search tab. `HomeItemCard` is a fixed-width
//  tile built for horizontal carousels; search results render as a vertical
//  list instead, so this gets its own row rather than reusing that card.
//

import SwiftUI

struct SearchResultRow: View {
    let item: StoredItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if item.isImportant {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("Last seen \(item.lastSeenAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)")
        .accessibilityHint("Opens the item detail.")
    }

    private var thumbnail: some View {
        AsyncStoredImage(path: item.imagePath, contentMode: .fill, placeholderSymbol: item.category.symbolName)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}
