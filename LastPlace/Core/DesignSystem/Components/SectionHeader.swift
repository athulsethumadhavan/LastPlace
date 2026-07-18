//
//  SectionHeader.swift
//  LastPlace
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        _ title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.heading(19))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppColor.accent)
            }
        }
    }
}
