//
//  RecentItemsWidget.swift
//  LastPlaceWidget
//
//  Answers "where did I put X" from the home screen — shows starred items
//  if there are any, recent items otherwise. See `WidgetDataProvider`.
//

import WidgetKit
import SwiftUI

struct RecentItemsEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItemInfo]
}

struct RecentItemsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentItemsEntry {
        RecentItemsEntry(date: Date(), items: Self.sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentItemsEntry) -> Void) {
        if context.isPreview {
            completion(RecentItemsEntry(date: Date(), items: Self.sampleItems))
            return
        }
        Task {
            let items = await WidgetDataProvider.fetchHighlightItems()
            completion(RecentItemsEntry(date: Date(), items: items))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentItemsEntry>) -> Void) {
        Task {
            let items = await WidgetDataProvider.fetchHighlightItems()
            let entry = RecentItemsEntry(date: Date(), items: items)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
                ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    static let sampleItems: [WidgetItemInfo] = [
        WidgetItemInfo(id: UUID(), name: "Passport", locationDescription: "Top drawer", roomName: "Bedroom"),
        WidgetItemInfo(id: UUID(), name: "Keys", locationDescription: "By the front door", roomName: "Entryway")
    ]
}

struct RecentItemsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentItemsEntry

    private var visibleItems: [WidgetItemInfo] {
        let limit: Int
        switch family {
        case .systemSmall: limit = 2
        case .systemMedium: limit = 3
        default: limit = 6
        }
        return Array(entry.items.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("LastPlace", systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if visibleItems.isEmpty {
                Text("No items saved yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleItems) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text("\(item.roomName) — \(item.locationDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentItemsWidget: Widget {
    let kind: String = "RecentItemsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentItemsProvider()) { entry in
            RecentItemsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Items")
        .description("See where your recently updated or starred items are.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
