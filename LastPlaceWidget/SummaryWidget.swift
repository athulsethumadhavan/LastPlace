//
//  SummaryWidget.swift
//  LastPlaceWidget
//
//  A quick at-a-glance count of everything LastPlace is tracking. Reuses
//  `DefaultFetchDataSummaryUseCase`, same as the Data Management screen.
//

import WidgetKit
import SwiftUI

struct SummaryEntry: TimelineEntry {
    let date: Date
    let summary: DataSummary?
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: Date(), summary: DataSummary(roomCount: 4, itemCount: 23, checklistCount: 2))
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let summary = await WidgetDataProvider.fetchSummary()
            completion(SummaryEntry(date: Date(), summary: summary))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        Task {
            let summary = await WidgetDataProvider.fetchSummary()
            let entry = SummaryEntry(date: Date(), summary: summary)
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
                ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

struct SummaryWidgetView: View {
    let entry: SummaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("LastPlace", systemImage: "house")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let summary = entry.summary {
                statRow(value: summary.roomCount, label: "Rooms")
                statRow(value: summary.itemCount, label: "Items")
                statRow(value: summary.checklistCount, label: "Checklists")
            } else {
                Text("No data yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(value: Int, label: String) -> some View {
        HStack {
            Text("\(value)")
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SummaryWidget: Widget {
    let kind: String = "SummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Summary")
        .description("A quick count of everything LastPlace is tracking.")
        .supportedFamilies([.systemSmall])
    }
}
