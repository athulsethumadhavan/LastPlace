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
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                        if item.isImportant {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)
                        .font(AppFont.body(12.5))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                    Text("Last seen \(item.lastSeenAt.formatted(.relative(presentation: .named)))")
                        .font(AppFont.body(11))
                        .foregroundStyle(AppColor.textTertiary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.locationDescription.isEmpty ? item.category.displayName : item.locationDescription)")
        .accessibilityHint("Opens the item detail.")
    }

    private var thumbnail: some View {
        AsyncStoredImage(path: item.imagePath, contentMode: .fill, placeholderSymbol: item.category.symbolName)
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.plateRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
