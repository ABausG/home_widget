// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ForecastHomeWidgetEntry {
    ForecastHomeWidgetEntry(date: Date(), data: ForecastData.fromUserDefaults(nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (ForecastHomeWidgetEntry) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = ForecastData.fromUserDefaults(prefs)

    completion(ForecastHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let timedEntries = ForecastData.loadTimedEntries(prefs)
    let now = Date()
    var entries: [ForecastHomeWidgetEntry] = [
      ForecastHomeWidgetEntry(
        date: now,
        data: ForecastData.fromUserDefaults(prefs, at: now, timedEntries: timedEntries)
      )
    ]
    for timedEntry in timedEntries where timedEntry.date > now {
      entries.append(
        ForecastHomeWidgetEntry(
          date: timedEntry.date,
          data: ForecastData.fromUserDefaults(
            prefs, at: timedEntry.date, timedEntries: timedEntries)
        )
      )
    }
    completion(Timeline(entries: entries, policy: .atEnd))

  }
}

struct ForecastHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: ForecastData
}

struct ForecastHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading) {
      Text(entry.data.city ?? "")
        .font(.caption)
      Text(entry.data.condition ?? "")
        .font(.title).fontWeight(.bold)
      Text(entry.data.temperature != nil ? "\(entry.data.temperature!)" : "0")
    }
    .applyContainerBackground()
  }
}

struct ForecastHomeWidget: Widget {
  let kind: String = "ForecastHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ForecastHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Forecast")
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

struct ForecastData {
  let city: String?
  let condition: String?
  let temperature: Int?

  static let paramPrefix = "home_widget.Forecast"

  static func fromUserDefaults(
    _ defaults: UserDefaults?,
    at date: Date = Date(),
    timedEntries: [(date: Date, values: [String: Any])]? = nil
  ) -> ForecastData {
    let timedValues = activeTimedValues(timedEntries ?? loadTimedEntries(defaults), at: date)
    return ForecastData(
      city: (defaults?.string(forKey: "\(paramPrefix).city") ?? "Nowhere"),
      condition: (timedValues["condition"] as? String) ?? "No forecast",
      temperature: (timedValues["temperature"] as? Int) ?? 0,
    )
  }

  fileprivate static func loadTimedEntries(_ defaults: UserDefaults?) -> [(
    date: Date, values: [String: Any]
  )] {
    guard let path = defaults?.string(forKey: "\(paramPrefix).timedData") else { return [] }
    guard FileManager.default.fileExists(atPath: path) else { return [] }
    do {
      let raw = try Data(contentsOf: URL(fileURLWithPath: path))
      guard let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
        return []
      }
      var entries: [(date: Date, values: [String: Any])] = []
      for (key, value) in json {
        guard let millis = Double(key), let values = value as? [String: Any] else { continue }
        entries.append((date: Date(timeIntervalSince1970: millis / 1000), values: values))
      }
      entries.sort { $0.date < $1.date }
      return entries
    } catch {
      return []
    }
  }

  fileprivate static func activeTimedValues(
    _ entries: [(date: Date, values: [String: Any])], at date: Date
  ) -> [String: Any] {
    var values: [String: Any] = [:]
    for entry in entries {
      if entry.date > date { break }
      values = entry.values
    }
    return values
  }
}
