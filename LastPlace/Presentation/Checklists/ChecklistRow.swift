//
//  ChecklistRow.swift
//  LastPlace
//

import SwiftUI

struct ChecklistRow: View {
    let checklist: Checklist
    let progress: ChecklistsListViewModel.Progress?
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: checklist.type.symbolName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColor.accent)
                        .frame(width: 42, height: 42)
                        .background(AppColor.surface, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(checklist.name)
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(AppFont.body(12.5))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 58)

                if showsDivider {
                    Rectangle()
                        .fill(AppColor.divider)
                        .frame(height: 1)
                        .padding(.leading, 14 + 42 + 12)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(checklist.name), \(subtitle)")
        .accessibilityHint("Opens the checklist.")
    }

    private var isComplete: Bool {
        guard let progress, progress.total > 0 else { return false }
        return progress.completed == progress.total
    }

    private var subtitle: String {
        guard let progress, progress.total > 0 else { return checklist.type.displayName }
        return "\(checklist.type.displayName) · \(progress.completed) of \(progress.total) done"
    }
}
