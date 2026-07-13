//
//  RoomCard.swift
//  LastPlace
//

import SwiftUI

struct RoomCard: View {
    let room: Room
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppCard {
                VStack(alignment: .leading, spacing: 0) {
                    coverImage
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Text(updatedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(room.name), updated \(updatedText)")
        .accessibilityHint("Opens the room detail.")
    }

    private var coverImage: some View {
        ZStack(alignment: .topLeading) {
            AsyncStoredImage(path: room.coverImagePath, contentMode: .fill, placeholderSymbol: room.iconName)
                .frame(height: 100)
                .clipped()

            Image(systemName: room.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
                .padding(8)
                .accessibilityHidden(true)
        }
    }

    private var updatedText: String {
        room.updatedAt.formatted(.relative(presentation: .named))
    }
}
