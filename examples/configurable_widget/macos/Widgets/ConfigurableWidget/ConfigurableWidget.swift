//
//  ConfigurableWidget.swift
//  ConfigurableWidget
//

import SwiftUI
import WidgetKit

@available(macOS 14.0, *)
struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), name: "World", punctuation: "!")
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    SimpleEntry(
      date: Date(), name: configuration.name, punctuation: configuration.punctuation?.id ?? "!")
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
    SimpleEntry
  > {
    var entries: [SimpleEntry] = []

    // Generate a timeline consisting of five entries an hour apart, starting from the current date.
    let currentDate = Date()
    for hourOffset in 0..<5 {
      let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
      let entry = SimpleEntry(
        date: entryDate, name: configuration.name, punctuation: configuration.punctuation?.id ?? "!"
      )
      entries.append(entry)
    }

    return Timeline(entries: entries, policy: .atEnd)
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let name: String?
  var punctuation: String?
}

struct ConfigurableWidgetEntryView: View {
  var entry: SimpleEntry

  var body: some View {
    VStack {
      Text("Hello")
      if let name = entry.name {
        Text(name)
      }
      if let punctuation = entry.punctuation {
        Text(punctuation)
      }
    }
  }
}

struct ConfigurableWidget: Widget {
  let kind = "ConfigurableWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) {
      entry in
      ConfigurableWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Configurable Widget")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
