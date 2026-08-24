// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ThemedCounterHomeWidgetEntry {
    ThemedCounterHomeWidgetEntry(date: Date(), data: ThemedCounterData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (ThemedCounterHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = ThemedCounterData.fromUserDefaults(prefs)

    completion(ThemedCounterHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = ThemedCounterData.fromUserDefaults(prefs)

    completion(
      Timeline(entries: [ThemedCounterHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct ThemedCounterHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: ThemedCounterData
}

struct ThemedCounterHomeWidgetEntryView: View {
  var entry: Provider.Entry

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    VStack(alignment: .center) {
      Spacer()
      Text("Counter")
        .font(.caption).foregroundColor(Color.secondary)
      Text(entry.data.count != nil ? "\(entry.data.count!)" : "0")
        .font(.title).fontWeight(.bold).foregroundColor(Color.primary)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .applyContainerBackground(
      (colorScheme == .dark
        ? Color(
          red: 0.043137254901960784, green: 0.07058823529411765, blue: 0.12549019607843137,
          opacity: 1.0)
        : Color(red: 0.9372549019607843, green: 0.9647058823529412, blue: 1.0, opacity: 1.0)))
  }
}

struct ThemedCounterHomeWidget: Widget {
  let kind: String = "ThemedCounterHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ThemedCounterHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Themed Counter")
    .description("A counter with a themed background and role-based colors.")
    .supportedFamilies([.systemSmall])
  }
}

extension View {
  @ViewBuilder
  func applyContainerBackground<T: View>(_ backgroundView: T) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) { backgroundView }
    } else {
      self.background(backgroundView)
    }
  }
}

struct ThemedCounterData {
  let count: Int?

  static let paramPrefix = "home_widget.ThemedCounter"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> ThemedCounterData {
    return ThemedCounterData(
      count: (defaults?.object(forKey: "\(paramPrefix).count") as? Int ?? 0),
    )
  }
}
