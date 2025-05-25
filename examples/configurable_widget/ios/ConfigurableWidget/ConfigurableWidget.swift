//
//  ConfigurableWidget.swift
//  ConfigurableWidget
//

import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), name: "World", punctuation: "!")
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    SimpleEntry(date: Date(), name: configuration.name, punctuation: configuration.punctuation.id)
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
        date: entryDate, name: configuration.name, punctuation: configuration.punctuation.id)
      entries.append(entry)
    }

    return Timeline(entries: entries, policy: .atEnd)
  }
}

struct IntentProvider: IntentTimelineProvider {
  typealias Entry = SimpleEntry

  typealias Intent = GreetingIntentIntent

  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), name: "World")
  }

  func getSnapshot(
    for configuration: GreetingIntentIntent, in context: Context,
    completion: @escaping (SimpleEntry) -> Void
  ) {
    completion(SimpleEntry(date: Date(), name: configuration.Name))
  }

  func getTimeline(
    for configuration: GreetingIntentIntent, in context: Context,
    completion: @escaping (Timeline<SimpleEntry>) -> Void
  ) {
    var entries: [SimpleEntry] = []

    // Generate a timeline consisting of five entries an hour apart, starting from the current date.
    let currentDate = Date()
    for hourOffset in 0..<5 {
      let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
      let entry = SimpleEntry(
        date: entryDate, name: configuration.Name,
        punctuation: configuration.Punctuation?.identifier)
      entries.append(entry)
    }

    completion(Timeline(entries: entries, policy: .atEnd))
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
  let kind: String = "ConfigurableWidget"

  var body: some WidgetConfiguration {
    if #available(iOS 17.0, *) {
      return AppIntentConfiguration(
        kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()
      ) {
        entry in
        ConfigurableWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      }
    } else {
      return IntentConfiguration(
        kind: kind,
        intent: GreetingIntentIntent.self,
        provider: IntentProvider()
      ) { entry in
        ConfigurableWidgetEntryView(entry: entry)
      }
    }
  }
}
