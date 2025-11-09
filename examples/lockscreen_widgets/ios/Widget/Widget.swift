//
//  Widget.swift
//  Widget
//
//  Created by Anton Borries on 09.11.25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), counter: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let prefs = UserDefaults(suiteName: "group.es.antonborri.lockscreenWidgets")
        let counter = prefs?.integer(forKey: "counter") ?? 0
        let entry = SimpleEntry(date: Date(), counter: counter)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { (entry) in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let counter: Int
}

struct WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Text("\(entry.counter)")
            .font(.system(size: 50, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .widgetURL(URL(string: "homeWidgetExample://counter?count=\(entry.counter)&homeWidget"))
    }
}

struct LockScreenWidget: Widget {
    let kind: String = "LockscreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Counter Widget")
        .description("Lock Screen Widget")
        .supportedFamilies([.accessoryCircular])
    }
}
