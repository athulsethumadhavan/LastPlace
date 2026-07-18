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
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColor.accent)
                                    .accessibilityHidden(true)
                            }
                            Text(item.name)
                                .font(AppFont.body(13.5, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(AppColor.textPrimary)
                        }
                        Text(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)
                            .font(AppFont.body(11.5))
                            .foregroundStyle(AppColor.textSecondary)
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
