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
                    iconBanner
                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.name)
                            .font(AppFont.body(14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(AppColor.textPrimary)
                        Text(updatedText)
                            .font(AppFont.body(11.5))
                            .foregroundStyle(AppColor.textSecondary)
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

    /// Rooms don't have a cover photo pipeline yet — `coverImagePath` is
    /// always nil today (see `CreateRoomViewModel`/`EditRoomViewModel`) — so
    /// this is a single icon on a tinted field rather than an `AsyncStoredImage`
    /// pretending to be a photo with a duplicate icon badge on top of it.
    private var iconBanner: some View {
        ZStack {
            AppColor.surface
            Image(systemName: room.iconName)
                .font(.title2)
                .foregroundStyle(AppColor.accent)
                .accessibilityHidden(true)
        }
        .frame(height: 66)
    }

    private var updatedText: String {
        room.updatedAt.formatted(.relative(presentation: .named))
    }
}
