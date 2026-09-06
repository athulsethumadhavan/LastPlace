//
//  IconChoice.swift
//  LastPlace
//
//  Single SF Symbol chip used in icon-picker grids. Shared by `CreateRoomView`
//  and `EditRoomView` so both stay visually identical.
//

import SwiftUI

struct IconChoice: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
