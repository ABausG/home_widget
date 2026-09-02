// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> WidgetLinkHomeWidgetEntry {
    WidgetLinkHomeWidgetEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (WidgetLinkHomeWidgetEntry) -> Void) {
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    // let counter = prefs?.integer(forKey: "counter") ?? 0
    completion(WidgetLinkHomeWidgetEntry(date: Date()))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [WidgetLinkHomeWidgetEntry(date: Date())], policy: .atEnd))

  }
}

struct WidgetLinkHomeWidgetEntry: TimelineEntry {
  let date: Date
}

struct WidgetLinkHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading) {
      Text("Tap me")
        .font(.caption)
      Text("Opens the app")
        .font(.title).fontWeight(.bold)
    }
    .applyContainerBackground()
    .widgetURL(URL(string: "generatorBasics://link?homeWidget"))
  }
}

struct WidgetLinkHomeWidget: Widget {
  let kind: String = "WidgetLinkHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      WidgetLinkHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Widget Link")
    .supportedFamilies([.systemSmall])
  }
}

extension View {
  @ViewBuilder
  func applyContainerBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(.fill.tertiary, for: .widget)
    } else if #available(iOSApplicationExtension 15.0, *) {
      self.background()
    } else {
      self
    }
  }
}
