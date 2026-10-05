// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: WidgetLinkHomeWidgetFlavor.appGroupId

import SwiftUI
import WidgetKit

enum WidgetLinkHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> WidgetLinkHomeWidgetEntry {
    WidgetLinkHomeWidgetEntry(date: Date(), data: WidgetLinkData.fromUserDefaults(nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (WidgetLinkHomeWidgetEntry) -> Void) {
    let prefs = UserDefaults(suiteName: WidgetLinkHomeWidgetFlavor.appGroupId)
    let data = WidgetLinkData.fromUserDefaults(prefs)

    completion(WidgetLinkHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: WidgetLinkHomeWidgetFlavor.appGroupId)
    let data = WidgetLinkData.fromUserDefaults(prefs)

    completion(
      Timeline(entries: [WidgetLinkHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct WidgetLinkHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: WidgetLinkData
}

struct WidgetLinkHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Tap me")
        .font(.caption)
      Text("Opens the app")
        .font(.title).fontWeight(.bold)
        .padding(.top, 8.0)
      HStack(alignment: .center, spacing: 0) {
        hwLink(
          hwPayloadUrl(
            "generatorBasics://topic",
            [("topic", hwPayloadValue(entry.data.topic)), ("position", "1")], "homeWidget", "")
        ) {
          Text(entry.data.topic ?? "")
        }
        hwLink(URL(string: "generatorBasics://settings?homeWidget")) {
          Text("Settings")
        }
        .padding(.leading, 16.0)
      }
      .padding(.top, 8.0)
    }
    .applyContainerBackground()
    .widgetURL(URL(string: "generatorBasics://link?homeWidget"))
  }
}

struct WidgetLinkHomeWidget: Widget {
  let kind: String = "WidgetLinkHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      WidgetLinkHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Widget Link")
    .supportedFamilies([.systemMedium])
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

struct WidgetLinkData {
  let topic: String?

  static let paramPrefix = "home_widget.WidgetLink"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> WidgetLinkData {
    return WidgetLinkData(
      topic: (defaults?.string(forKey: "\(paramPrefix).topic") ?? "Widgets"),
    )
  }
}

func hwLink<Content: View>(_ url: URL?, @ViewBuilder content: () -> Content) -> some View {
  return Group {
    if let url = url {
      Link(destination: url, label: content)
        .buttonStyle(.plain)
    } else {
      content()
    }
  }
}

func hwPayloadUrl(
  _ head: String, _ payload: [(String, String?)], _ marker: String, _ fragment: String
) -> URL? {
  let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
  var url = head
  var separator = head.contains("?") ? "&" : "?"
  for (name, value) in payload {
    guard let value = value,
      let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved)
    else { continue }
    url += separator + name + "=" + encoded
    separator = "&"
  }
  if !marker.isEmpty {
    url += separator + marker
  }
  return URL(string: url + fragment)
}

func hwPayloadValue(_ value: String?) -> String? {
  return value
}

func hwPayloadValue(_ value: Int?) -> String? {
  return value.map { String($0) }
}

func hwPayloadValue(_ value: Double?) -> String? {
  return value.map {
    $0.isNaN ? "NaN" : $0.isInfinite ? ($0 < 0 ? "-Infinity" : "Infinity") : String($0)
  }
}

func hwPayloadValue(_ value: Bool?) -> String? {
  return value.map { $0 ? "true" : "false" }
}

func hwPayloadValue(_ value: Date?) -> String? {
  return value.map { String(Int64(($0.timeIntervalSince1970 * 1000).rounded())) }
}
