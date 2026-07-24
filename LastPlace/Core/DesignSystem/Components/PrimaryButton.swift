//
//  PrimaryButton.swift
//  LastPlace
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let symbolName: String?
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        symbolName: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbolName = symbolName
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if let symbolName {
                    Image(systemName: symbolName)
                }
                Text(title)
                    .font(AppFont.heading(16))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .appCardShadow()
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }
}
