// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SimpleDataHomeWidgetEntry {
    SimpleDataHomeWidgetEntry(date: Date(), data: SimpleDataData.fromUserDefaults(nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (SimpleDataHomeWidgetEntry) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = SimpleDataData.fromUserDefaults(prefs)

    completion(SimpleDataHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = SimpleDataData.fromUserDefaults(prefs)

    completion(Timeline(entries: [SimpleDataHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct SimpleDataHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: SimpleDataData
}


struct SimpleDataHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
        VStack {
            Text("Simple Data")
            HStack {
                Text("label: ")
                Text(entry.data.label ?? "")
            }
            HStack {
                Text("value: ")
                Text(entry.data.value != nil ? "\(entry.data.value!)" : "0")
            }
        }
  }
}

struct SimpleDataHomeWidget: Widget {
  let kind: String = "SimpleDataHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      SimpleDataHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Simple Data")
    .supportedFamilies([.systemSmall])
  }
}

struct SimpleDataData {
  let label: String?
  let value: Int?

  static let paramPrefix = "home_widget.SimpleData"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> SimpleDataData {
    return SimpleDataData(
      label: defaults?.string(forKey: "\(paramPrefix).label"),
      value: defaults?.object(forKey: "\(paramPrefix).value") as? Int,
    )
  }
}

