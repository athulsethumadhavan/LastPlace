//
//  ChecklistProgressWidget.swift
//  LastPlaceWidget
//
//  Shows how far along the most relevant checklist is — see
//  `WidgetDataProvider.fetchActiveChecklistProgress()` for how "most
//  relevant" is picked.
//

import WidgetKit
import SwiftUI

struct ChecklistProgressEntry: TimelineEntry {
    let date: Date
    let progress: WidgetChecklistProgress?
}

struct ChecklistProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChecklistProgressEntry {
        ChecklistProgressEntry(date: Date(), progress: Self.sampleProgress)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChecklistProgressEntry) -> Void) {
        if context.isPreview {
            completion(ChecklistProgressEntry(date: Date(), progress: Self.sampleProgress))
            return
        }
        Task {
            let progress = await WidgetDataProvider.fetchActiveChecklistProgress()
            completion(ChecklistProgressEntry(date: Date(), progress: progress))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChecklistProgressEntry>) -> Void) {
        Task {
            let progress = await WidgetDataProvider.fetchActiveChecklistProgress()
            let entry = ChecklistProgressEntry(date: Date(), progress: progress)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
                ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    static let sampleProgress = WidgetChecklistProgress(
        checklistName: "Leaving Home",
        completedCount: 2,
        totalCount: 5,
        remainingTitles: ["Keys", "Wallet", "Sunglasses"]
    )
}

struct ChecklistProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ChecklistProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Checklist", systemImage: "checklist")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let progress = entry.progress {
                Text(progress.checklistName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                ProgressView(
                    value: progress.totalCount > 0
                        ? Double(progress.completedCount) / Double(progress.totalCount)
                        : 0
                )
                .tint(.accentColor)

                Text("\(progress.completedCount) of \(progress.totalCount) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if family == .systemMedium, !progress.remainingTitles.isEmpty {
                    Text(progress.remainingTitles.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("No checklists yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChecklistProgressWidget: Widget {
    let kind: String = "ChecklistProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChecklistProgressProvider()) { entry in
            ChecklistProgressWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Checklist Progress")
        .description("Track how far along your active checklist is.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
