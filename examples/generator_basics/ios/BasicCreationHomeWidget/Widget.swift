// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> BasicCreationHomeWidgetEntry {
    BasicCreationHomeWidgetEntry(date: Date())
  }

  func getSnapshot(
    in context: Context, completion: @escaping (BasicCreationHomeWidgetEntry) -> Void
  ) {
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    // let counter = prefs?.integer(forKey: "counter") ?? 0
    completion(BasicCreationHomeWidgetEntry(date: Date()))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [BasicCreationHomeWidgetEntry(date: Date())], policy: .atEnd))

  }
}

struct BasicCreationHomeWidgetEntry: TimelineEntry {
  let date: Date
}

struct BasicCreationHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack {
      Text("Basic Creation")
    }
    .applyContainerBackground()
  }
}

struct BasicCreationHomeWidget: Widget {
  let kind: String = "BasicCreationHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      BasicCreationHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Basic Creation")
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
