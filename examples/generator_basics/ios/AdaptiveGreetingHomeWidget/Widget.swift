// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> AdaptiveGreetingHomeWidgetEntry {
    AdaptiveGreetingHomeWidgetEntry(date: Date())
  }

  func getSnapshot(
    in context: Context, completion: @escaping (AdaptiveGreetingHomeWidgetEntry) -> Void
  ) {
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    // let counter = prefs?.integer(forKey: "counter") ?? 0
    completion(AdaptiveGreetingHomeWidgetEntry(date: Date()))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [AdaptiveGreetingHomeWidgetEntry(date: Date())], policy: .atEnd))

  }
}

struct AdaptiveGreetingHomeWidgetEntry: TimelineEntry {
  let date: Date
}

struct AdaptiveGreetingHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    Text("Hello iOS")
      .font(.headline)
      .applyContainerBackground()
  }
}

struct AdaptiveGreetingHomeWidget: Widget {
  let kind: String = "AdaptiveGreetingHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      AdaptiveGreetingHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Adaptive Greeting")
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
