// macOS version of the generated iOS example. See ../../../README.md.
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: AdaptiveGreetingHomeWidgetFlavor.appGroupId

import SwiftUI
import WidgetKit

enum AdaptiveGreetingHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> AdaptiveGreetingHomeWidgetEntry {
    AdaptiveGreetingHomeWidgetEntry(date: Date())
  }

  func getSnapshot(
    in context: Context, completion: @escaping (AdaptiveGreetingHomeWidgetEntry) -> Void
  ) {
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: AdaptiveGreetingHomeWidgetFlavor.appGroupId)
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
    Text("Hello macOS")
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
    if #available(macOS 14.0, *) {
      self.containerBackground(.fill.tertiary, for: .widget)
    } else if #available(macOS 12.0, *) {
      self.background()
    } else {
      self
    }
  }
}
