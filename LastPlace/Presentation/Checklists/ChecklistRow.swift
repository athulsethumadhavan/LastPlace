//
//  ChecklistRow.swift
//  LastPlace
//

import SwiftUI

struct ChecklistRow: View {
    let checklist: Checklist
    let progress: ChecklistsListViewModel.Progress?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: checklist.type.symbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(checklist.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
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
