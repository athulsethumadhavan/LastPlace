//
//  HomeItemCard.swift
//  LastPlace
//
//  Small item tile used in the horizontal "Recent" and "Important" strips.
//

import SwiftUI

struct HomeItemCard: View {
    let item: StoredItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppCard {
                VStack(alignment: .leading, spacing: 0) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if item.isImportant {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                    .accessibilityHidden(true)
                            }
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                        Text(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 150)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.locationDescription)")
        .accessibilityHint("Opens the item detail.")
    }

    private var thumbnail: some View {
        AsyncStoredImage(path: item.imagePath, contentMode: .fill, placeholderSymbol: item.category.symbolName)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipped()
    }
}
