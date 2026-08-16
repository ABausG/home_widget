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
      Text(
        hwLocalize(["en": "Greeting", "de": "Begrüßung", "pt-BR": "Saudação"], baseLocale: "en")
      )
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
      hwLocalize(
        [
          "en": "Localized Greeting", "de": "Lokalisierte Begrüßung",
          "pt-BR": "Saudação Localizada",
        ], baseLocale: "en")
    )
    .description(
      hwLocalize(
        [
          "en": "Greets you in your language", "de": "Begrüßt dich in deiner Sprache",
          "pt-BR": "Cumprimenta você no seu idioma",
        ], baseLocale: "en")
    )
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

func hwCurrentLocale() -> String {
  let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
  return identifier.replacingOccurrences(of: "_", with: "-")
}

func hwLocalize(_ values: [String: String], baseLocale: String) -> String {
  let tag = hwCurrentLocale()
  if let exact = values[tag] { return exact }
  if let language = tag.split(separator: "-").first,
    let match = values[String(language)]
  {
    return match
  }
  return values[baseLocale] ?? ""
}

func hwReadLocalized(
  _ defaults: UserDefaults?,
  _ key: String,
  _ values: [String: String],
  baseLocale: String
) -> String {
  let tag = hwCurrentLocale()
  if let exact = defaults?.string(forKey: "\(key).\(tag)") { return exact }
  if let language = tag.split(separator: "-").first,
    let match = defaults?.string(forKey: "\(key).\(language)")
  {
    return match
  }
  if let fallback = defaults?.string(forKey: "\(key).\(baseLocale)") {
    return fallback
  }
  return hwLocalize(values, baseLocale: baseLocale)
}
