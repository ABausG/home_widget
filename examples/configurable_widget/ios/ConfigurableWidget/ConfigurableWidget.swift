//
//  ConfigurableWidget.swift
//  ConfigurableWidget
//
//  Created by Anton Borries on 23.10.24.
//

import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    SimpleEntry(date: Date(), configuration: configuration)
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
    SimpleEntry
  > {
    var entries: [SimpleEntry] = []

    // Generate a timeline consisting of five entries an hour apart, starting from the current date.
    let currentDate = Date()
    for hourOffset in 0..<5 {
      let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
      let entry = SimpleEntry(date: entryDate, configuration: configuration)
      entries.append(entry)
    }

    return Timeline(entries: entries, policy: .atEnd)
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationAppIntent
}

struct ConfigurableWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack {
      Text("Hello")
      Text(entry.configuration.name)
      Text(entry.configuration.punctuation.id)
    }
  }
}

struct ConfigurableWidget: Widget {
  let kind: String = "ConfigurableWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) {
      entry in
      ConfigurableWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
  }
}

extension ConfigurationAppIntent {
  fileprivate static var smiley: ConfigurationAppIntent {
    let intent = ConfigurationAppIntent()
    intent.name = "World"
    return intent
  }

  fileprivate static var starEyes: ConfigurationAppIntent {
    let intent = ConfigurationAppIntent()
    intent.name = "Anton"
    return intent
  }
}

#Preview(as: .systemSmall) {
  ConfigurableWidget()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley)
  SimpleEntry(date: .now, configuration: .starEyes)
}
