// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> LocalizedGreetingHomeWidgetEntry {
    LocalizedGreetingHomeWidgetEntry(
      date: Date(), data: LocalizedGreetingData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (LocalizedGreetingHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = LocalizedGreetingData.fromUserDefaults(prefs)

    completion(LocalizedGreetingHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = LocalizedGreetingData.fromUserDefaults(prefs)

    completion(
      Timeline(
        entries: [LocalizedGreetingHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct LocalizedGreetingHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: LocalizedGreetingData
}

struct LocalizedGreetingHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = LocalizedGreetingData.fromUserDefaults(prefs)
    VStack(alignment: .leading) {
      Text(NSLocalizedString("home_widget_localized_greeting_t_1e28f816", comment: ""))
        .font(.caption)
      Text(data.greeting ?? "")
        .font(.title).fontWeight(.bold)
    }
    .applyContainerBackground()
  }
}

struct LocalizedGreetingHomeWidget: Widget {
  let kind: String = "LocalizedGreetingHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      LocalizedGreetingHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(
      NSLocalizedString("home_widget_localized_greeting_label", comment: "")
    )
    .description(NSLocalizedString("home_widget_localized_greeting_description", comment: ""))
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

struct LocalizedGreetingData {
  let greeting: String?

  static let paramPrefix = "home_widget.LocalizedGreeting"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> LocalizedGreetingData {
    return LocalizedGreetingData(
      greeting: hwReadLocalized(
        defaults, "\(paramPrefix).greeting", ["en": "Hello", "de": "Hallo", "pt-BR": "Olá"],
        baseLocale: "en"),
    )
  }
}

func hwCurrentLocales() -> [String] {
  let preferred = Locale.preferredLanguages.map {
    $0.replacingOccurrences(of: "_", with: "-")
  }
  if preferred.isEmpty {
    return [Locale.current.identifier.replacingOccurrences(of: "_", with: "-")]
  }
  return preferred
}

// Returns nil when nothing in `values` matches, so a caller holding a second
// tier of translations can fall through to it.
func hwResolveLocalized(
  _ locales: [String],
  _ values: [String: String],
  baseLocale: String
) -> String? {
  for tag in locales {
    if let exact = values[tag] { return exact }
    guard let prefix = tag.split(separator: "-").first else { continue }
    let language = String(prefix)
    if let match = values[language] { return match }
    // Same language, different region or script (pt-PT -> pt-BR). Keeps keyed
    // strings on the translation the OS already picks for resources. Smallest
    // key wins so the choice is stable across runs.
    let siblings = values.keys.filter {
      $0.split(separator: "-").first.map(String.init) == language
    }
    if let sibling = siblings.min(), let match = values[sibling] {
      return match
    }
  }
  return values[baseLocale]
}

func hwLocalize(_ values: [String: String], baseLocale: String) -> String {
  return hwResolveLocalized(hwCurrentLocales(), values, baseLocale: baseLocale) ?? ""
}

func hwReadLocalized(
  _ defaults: UserDefaults?,
  _ key: String,
  _ values: [String: String],
  baseLocale: String
) -> String {
  let locales = hwCurrentLocales()
  if let stored = hwDecodeLocalized(defaults?.string(forKey: key)),
    let match = hwResolveLocalized(locales, stored, baseLocale: baseLocale)
  {
    return match
  }
  return hwResolveLocalized(locales, values, baseLocale: baseLocale) ?? ""
}

func hwDecodeLocalized(_ raw: String?) -> [String: String]? {
  guard let raw, let data = raw.data(using: .utf8) else { return nil }
  guard let object = try? JSONSerialization.jsonObject(with: data),
    let json = object as? [String: Any]
  else { return nil }
  var values: [String: String] = [:]
  for (name, value) in json {
    if let text = value as? String { values[name] = text }
  }
  return values
}
