// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: WeekForecastHomeWidgetFlavor.appGroupId

import CoreText
import SwiftUI
import WidgetKit

enum WeekForecastHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> WeekForecastHomeWidgetEntry {
    WeekForecastHomeWidgetEntry(date: Date(), data: WeekForecastData.previewFromUserDefaults(nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (WeekForecastHomeWidgetEntry) -> Void)
  {
    if context.isPreview {
      let prefs: UserDefaults? = UserDefaults(suiteName: WeekForecastHomeWidgetFlavor.appGroupId)
      let data = WeekForecastData.previewFromUserDefaults(prefs)
      completion(WeekForecastHomeWidgetEntry(date: Date(), data: data))
      return
    }

    let prefs = UserDefaults(suiteName: WeekForecastHomeWidgetFlavor.appGroupId)
    let data = WeekForecastData.fromUserDefaults(prefs)

    completion(WeekForecastHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: WeekForecastHomeWidgetFlavor.appGroupId)
    let data = WeekForecastData.fromUserDefaults(prefs)

    completion(
      Timeline(entries: [WeekForecastHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct WeekForecastHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: WeekForecastData
}

struct WeekForecastHomeWidgetEntryView: View {
  var entry: Provider.Entry

  @Environment(\.layoutDirection) var layoutDirection

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(entry.data.city ?? "")
        .font(.headline)
      Spacer(minLength: 0)
      HStack(alignment: .center, spacing: 0) {
        if (entry.data.days ?? []).isEmpty {
          Text("Open the app to load the forecast")
            .font(.caption).foregroundColor(Color.secondary)
        } else {
          ForEach(Array((entry.data.days ?? []).prefix(5).enumerated()), id: \.offset) {
            hwIndex, hwItem in
            if hwIndex > 0 {
              Spacer(minLength: 0)
            }
            VStack(alignment: .center, spacing: 0) {
              Text(hwItem.day.map { hwFormatDateSkeleton($0, "E") } ?? "")
                .font(.caption).foregroundColor(Color.secondary)
              Group {
                if let codePoint = hwItem.condition, let value = UInt32(exactly: codePoint),
                  let scalar = UnicodeScalar(value)
                {
                  Text(String(scalar))
                    .font(hwBundledFont("hw_font_icons_materialicons", size: 24))
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color.primary)
                    .accessibilityHidden(true)
                    .scaleEffect(
                      x: layoutDirection == .rightToLeft && hwMirroredIcons.contains(codePoint)
                        ? -1 : 1, y: 1)
                }
              }
              .padding(.top, 4.0)
              HStack(alignment: .center, spacing: 0) {
                Text(
                  hwFormatDecimal(
                    NSNumber(value: hwItem.temperature ?? 0), minFraction: nil, maxFraction: nil,
                    grouping: true)
                )
                .font(.body)
                Text(entry.data.unit ?? "")
                  .font(.body)
              }
              .padding(.top, 4.0)
            }
            .padding(.leading, hwIndex > 0 ? 4.0 : 0)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .applyContainerBackground()
  }
}

struct WeekForecastHomeWidget: Widget {
  let kind: String = "WeekForecastHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      WeekForecastHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Week Forecast")
    .description("A five-day forecast, one column per day the app saves.")
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

struct WeekForecastData {
  let city: String?
  let unit: String?
  let days: [WeekForecastDaysItem]?

  static let paramPrefix = "home_widget.WeekForecast"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> WeekForecastData {
    return WeekForecastData(
      city: (defaults?.string(forKey: "\(paramPrefix).city") ?? "Nowhere"),
      unit: (defaults?.string(forKey: "\(paramPrefix).unit") ?? "°"),
      days: WeekForecastDaysItem.fromPath(defaults?.string(forKey: "\(paramPrefix).days")),
    )
  }

  static func previewFromUserDefaults(_ defaults: UserDefaults?) -> WeekForecastData {
    return WeekForecastData(
      city: (defaults?.string(forKey: "\(paramPrefix).city") ?? "Berlin"),
      unit: (defaults?.string(forKey: "\(paramPrefix).unit") ?? "°"),
      days: WeekForecastDaysItem.fromPath(defaults?.string(forKey: "\(paramPrefix).days"))
        ?? WeekForecastDaysItem.previewItems,
    )
  }
}

struct WeekForecastDaysItem {
  let day: Date?
  let condition: Int?
  let temperature: Int?

  static let previewItems: [WeekForecastDaysItem] = [
    WeekForecastDaysItem(
      day: hwParseIsoDate("2026-09-21T12:00:00Z"), condition: 59097, temperature: 21),
    WeekForecastDaysItem(
      day: hwParseIsoDate("2026-09-22T12:00:00Z"), condition: 57711, temperature: 18),
    WeekForecastDaysItem(
      day: hwParseIsoDate("2026-09-23T12:00:00Z"), condition: 59018, temperature: 14),
    WeekForecastDaysItem(
      day: hwParseIsoDate("2026-09-24T12:00:00Z"), condition: 985035, temperature: 16),
    WeekForecastDaysItem(
      day: hwParseIsoDate("2026-09-25T12:00:00Z"), condition: 59097, temperature: 22),
  ]

  static func fromPath(_ path: String?) -> [WeekForecastDaysItem]? {
    guard let path else { return nil }
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      let json = try JSONSerialization.jsonObject(with: data)
      return fromJsonArray(json)
    } catch {
      return nil
    }
  }

  static func fromJsonArray(_ value: Any?) -> [WeekForecastDaysItem]? {
    guard let items = value as? [Any] else { return nil }
    return items.map { fromJson($0 as? [String: Any]) }
  }

  static func fromJson(_ json: [String: Any]?) -> WeekForecastDaysItem {
    let values = json ?? [:]
    return WeekForecastDaysItem(
      day: hwParseIsoDate((values["day"] as? String) ?? ""),
      condition: (values["condition"] as? Int) ?? 57711,
      temperature: (values["temperature"] as? Int) ?? 0,
    )
  }
}

private let hwMirroredIcons: Set<Int> = []

private final class HWFontCache: @unchecked Sendable {
  static let shared = HWFontCache()

  private let lock = NSRecursiveLock()
  private var descriptors: [String: CTFontDescriptor?] = [:]
  private var fonts: [String: Font?] = [:]

  func font(_ key: String, _ size: CGFloat, _ build: () -> Font?) -> Font? {
    lock.lock()
    defer { lock.unlock() }
    let cacheKey = "\(key)|\(size)"
    if let cached = fonts[cacheKey] { return cached }
    let font = build()
    fonts[cacheKey] = font
    return font
  }

  func descriptor(_ url: URL) -> CTFontDescriptor? {
    lock.lock()
    defer { lock.unlock() }
    let path = url.path
    if let known = descriptors[path] { return known }
    let parsed =
      (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
      as? [CTFontDescriptor])?.first
    descriptors[path] = parsed
    return parsed
  }
}

func hwFontFromURL(_ url: URL, _ size: CGFloat) -> Font? {
  return HWFontCache.shared.font(url.path, size) { () -> Font? in
    guard let descriptor = HWFontCache.shared.descriptor(url) else { return nil }
    return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
  }
}

func hwBundledFont(_ name: String, size: CGFloat) -> Font {
  let font = HWFontCache.shared.font("bundle:" + name, size) { () -> Font? in
    for ext in ["otf", "ttf", "ttc"] {
      guard let url = Bundle.main.url(forResource: name, withExtension: ext)
      else { continue }
      if let font = hwFontFromURL(url, size) { return font }
    }
    return nil
  }
  return font ?? .system(size: size)
}

func hwFormatLocale() -> Locale {
  return Locale.current
}

func hwFormatDecimal(
  _ value: NSNumber, minFraction: Int?, maxFraction: Int?, grouping: Bool
) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  formatter.usesGroupingSeparator = grouping
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: value) ?? value.stringValue
}

func hwParseIsoDate(_ value: String) -> Date? {
  func normalize(_ raw: String) -> String {
    var body = raw.trimmingCharacters(in: .whitespaces)
    var zone = "Z"
    if let last = body.last, last == "Z" || last == "z" {
      body.removeLast()
    } else if let sign = body.lastIndex(where: { $0 == "+" || $0 == "-" }),
      body.distance(from: body.startIndex, to: sign) > 18
    {
      zone = String(body[sign...])
      body = String(body[body.startIndex..<sign])
    }
    var fraction = ""
    if let dot = body.firstIndex(of: ".") {
      fraction = String(body[body.index(after: dot)...]).filter { $0.isNumber }
      body = String(body[body.startIndex..<dot])
    }
    return body + "." + String((fraction + "000").prefix(3)) + zone
  }

  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.date(from: normalize(value))
}

func hwResolveTimeZone(_ id: String?) -> TimeZone {
  return id.flatMap { $0.isEmpty ? nil : TimeZone(identifier: $0) } ?? TimeZone.current
}

func hwFormatDateSkeleton(_ date: Date, _ skeleton: String, timeZone: String? = nil) -> String {
  let locale = hwFormatLocale()
  let formatter = DateFormatter()
  formatter.locale = locale
  formatter.timeZone = hwResolveTimeZone(timeZone)
  formatter.dateFormat =
    DateFormatter.dateFormat(fromTemplate: skeleton, options: 0, locale: locale) ?? skeleton
  return formatter.string(from: date)
}
