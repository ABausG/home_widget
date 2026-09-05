// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> NumberDateFormattingHomeWidgetEntry {
    NumberDateFormattingHomeWidgetEntry(
      date: Date(), data: NumberDateFormattingData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (NumberDateFormattingHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = NumberDateFormattingData.fromUserDefaults(prefs)

    completion(NumberDateFormattingHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = NumberDateFormattingData.fromUserDefaults(prefs)

    completion(
      Timeline(
        entries: [NumberDateFormattingHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct NumberDateFormattingHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: NumberDateFormattingData
}

struct NumberDateFormattingHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text("Order #")
          .font(.caption)
        Text(
          hwFormatDecimal(
            Double(entry.data.orderNumber ?? 0), minFraction: nil, maxFraction: nil, grouping: false
          )
        )
        .font(.caption)
        Text(" · ")
          .font(.caption)
        Text(entry.data.placedAt.map { hwFormatDateSkeleton($0, "yMMMd") } ?? "")
          .font(.caption)
      }
      Text(
        hwFormatCurrency(entry.data.total ?? 0.0, code: entry.data.currency ?? "", decimals: nil)
      )
      .font(.title).fontWeight(.bold)
      HStack {
        Text(hwFormatPercent(entry.data.discount ?? 0.0, minFraction: nil, maxFraction: nil))
        Text(" off · ")
        Text(
          hwFormatDecimal(
            Double(entry.data.items ?? 0), minFraction: nil, maxFraction: nil, grouping: true))
        Text(" items")
      }
      HStack {
        Text("Delivery ")
          .font(.caption)
        Text(
          entry.data.deliveryAt.map {
            hwFormatDateSkeleton($0, "jm", timeZone: entry.data.deliveryZone)
          } ?? ""
        )
        .font(.caption)
      }
      HStack {
        Text(hwFormatCompact(Double(entry.data.points ?? 0)))
          .font(.caption)
        Text(" of ")
          .font(.caption)
        Text(hwFormatDecimal(25000.0, minFraction: nil, maxFraction: nil, grouping: true))
          .font(.caption)
        Text(" points")
          .font(.caption)
      }
    }
    .applyContainerBackground()
  }
}

struct NumberDateFormattingHomeWidget: Widget {
  let kind: String = "NumberDateFormattingHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      NumberDateFormattingHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Number Date Formatting")
    .description("An order total, discount and delivery time, formatted on the device.")
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

struct NumberDateFormattingData {
  let orderNumber: Int?
  let placedAt: Date?
  let total: Double?
  let currency: String?
  let discount: Double?
  let items: Int?
  let deliveryAt: Date?
  let deliveryZone: String?
  let points: Int?

  static let paramPrefix = "home_widget.NumberDateFormatting"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> NumberDateFormattingData {
    return NumberDateFormattingData(
      orderNumber: (defaults?.object(forKey: "\(paramPrefix).orderNumber") as? Int ?? 0),
      placedAt: hwParseIsoDate(defaults?.string(forKey: "\(paramPrefix).placedAt") ?? ""),
      total: (defaults?.object(forKey: "\(paramPrefix).total") as? Double ?? 0.0),
      currency: (defaults?.string(forKey: "\(paramPrefix).currency") ?? "EUR"),
      discount: (defaults?.object(forKey: "\(paramPrefix).discount") as? Double ?? 0.0),
      items: (defaults?.object(forKey: "\(paramPrefix).items") as? Int ?? 0),
      deliveryAt: hwParseIsoDate(defaults?.string(forKey: "\(paramPrefix).deliveryAt") ?? ""),
      deliveryZone: (defaults?.string(forKey: "\(paramPrefix).deliveryZone") ?? ""),
      points: (defaults?.object(forKey: "\(paramPrefix).points") as? Int ?? 0),
    )
  }
}

func hwFormatLocale() -> Locale {
  return Locale.current
}

func hwFormatCompact(_ value: Double) -> String {
  if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
    return value.formatted(.number.notation(.compactName).locale(hwFormatLocale()))
  }
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}

func hwFormatCurrency(_ value: Double, code: String, decimals: Int?) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  let isoCode = code.uppercased()
  let isCode: Bool
  if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
    isCode = Locale.Currency.isoCurrencies.contains { $0.identifier.uppercased() == isoCode }
  } else {
    isCode = isoCode.count == 3 && isoCode.allSatisfy { $0.isLetter }
  }
  formatter.numberStyle = isCode ? .currency : .decimal
  if isCode { formatter.currencyCode = isoCode }
  if let decimals {
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
  }
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}

func hwFormatDecimal(
  _ value: Double, minFraction: Int?, maxFraction: Int?, grouping: Bool
) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  formatter.usesGroupingSeparator = grouping
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}

func hwFormatPercent(_ value: Double, minFraction: Int?, maxFraction: Int?) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .percent
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
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
