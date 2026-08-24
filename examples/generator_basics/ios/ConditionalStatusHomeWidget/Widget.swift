// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ConditionalStatusHomeWidgetEntry {
    ConditionalStatusHomeWidgetEntry(
      date: Date(), data: ConditionalStatusData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (ConditionalStatusHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = ConditionalStatusData.fromUserDefaults(prefs)

    completion(ConditionalStatusHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = ConditionalStatusData.fromUserDefaults(prefs)

    completion(
      Timeline(
        entries: [ConditionalStatusHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct ConditionalStatusHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: ConditionalStatusData
}

struct ConditionalStatusHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    Group {
      if entry.data.hasData != nil {
        if entry.data.enabled == true {
          VStack(alignment: .center) {
            Spacer()
            Text("Enabled")
              .font(.headline).foregroundColor(
                Color(
                  red: 0.08627450980392157, green: 0.6392156862745098, blue: 0.2901960784313726,
                  opacity: 1.0))
            Spacer()
          }
        } else {
          VStack(alignment: .center) {
            Spacer()
            Text("Disabled")
              .font(.headline).foregroundColor(
                Color(
                  red: 0.8627450980392157, green: 0.14901960784313725, blue: 0.14901960784313725,
                  opacity: 1.0))
            Spacer()
          }
        }
      } else {
        VStack(alignment: .center) {
          Spacer()
          Text("No Data")
            .font(.headline)
          Text("Open the app")
            .font(.caption).foregroundColor(Color.secondary)
          Spacer()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .applyContainerBackground()
  }
}

struct ConditionalStatusHomeWidget: Widget {
  let kind: String = "ConditionalStatusHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ConditionalStatusHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Conditional Status")
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

struct ConditionalStatusData {
  let hasData: Bool?
  let enabled: Bool?

  static let paramPrefix = "home_widget.ConditionalStatus"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> ConditionalStatusData {
    return ConditionalStatusData(
      hasData: defaults?.object(forKey: "\(paramPrefix).hasData") as? Bool,
      enabled: (defaults?.object(forKey: "\(paramPrefix).enabled") as? Bool ?? true),
    )
  }
}
