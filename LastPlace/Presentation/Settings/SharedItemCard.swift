//
//  SharedItemCard.swift
//  LastPlace
//
//  `HomeItemCard`'s sibling for shared-room content. Same layout, but the
//  thumbnail goes through `AsyncRemoteImage` with an on-demand Storage
//  download instead of `AsyncStoredImage`'s local file cache, since a
//  shared item's photo lives in another account's images.
//

import SwiftUI

struct SharedItemCard: View {
    let item: StoredItem
    let loadImage: (String) async throws -> Data
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.locationDescription)")
        .accessibilityHint("Opens the item detail.")
    }

    private var thumbnail: some View {
        AsyncRemoteImage(
            path: item.imagePath,
            contentMode: .fill,
            placeholderSymbol: item.category.symbolName,
            load: loadImage
        )
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
