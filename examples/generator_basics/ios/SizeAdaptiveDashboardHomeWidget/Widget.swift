// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: SizeAdaptiveDashboardHomeWidgetFlavor.appGroupId

import SwiftUI
import WidgetKit

enum SizeAdaptiveDashboardHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SizeAdaptiveDashboardHomeWidgetEntry {
    SizeAdaptiveDashboardHomeWidgetEntry(
      date: Date(), data: SizeAdaptiveDashboardData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (SizeAdaptiveDashboardHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: SizeAdaptiveDashboardHomeWidgetFlavor.appGroupId)
    let data = SizeAdaptiveDashboardData.fromUserDefaults(prefs)

    completion(SizeAdaptiveDashboardHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: SizeAdaptiveDashboardHomeWidgetFlavor.appGroupId)
    let data = SizeAdaptiveDashboardData.fromUserDefaults(prefs)

    completion(
      Timeline(
        entries: [SizeAdaptiveDashboardHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct SizeAdaptiveDashboardHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: SizeAdaptiveDashboardData
}

struct SizeAdaptiveDashboardHomeWidgetEntryView: View {
  var entry: Provider.Entry

  @Environment(\.widgetFamily) var widgetFamily

  var body: some View {
    Group {
      switch widgetFamily {
      case .systemMedium:
        HStack(alignment: .firstTextBaseline) {
          Spacer()
          Text(
            hwFormatDecimal(
              NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
              grouping: true)
          )
          .font(.title).fontWeight(.bold)
          Text(entry.data.scoreLabel ?? "")
            .font(.body).foregroundColor(Color.secondary)
            .padding(EdgeInsets(top: 0.0, leading: 8.0, bottom: 0.0, trailing: 0.0))
          Spacer()
        }
      case .systemLarge:
        VStack(alignment: .leading) {
          Text(
            hwFormatDecimal(
              NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
              grouping: true)
          )
          .font(.title).fontWeight(.bold)
          Text(entry.data.scoreLabel ?? "")
            .font(.body).foregroundColor(Color.secondary)
          Text(
            hwFormatDecimal(
              NSNumber(value: entry.data.streak ?? 0), minFraction: nil, maxFraction: nil,
              grouping: true)
          )
          .font(.caption)
          .padding(EdgeInsets(top: 8.0, leading: 0.0, bottom: 0.0, trailing: 0.0))
        }
      case .accessoryCircular:
        Text(
          hwFormatDecimal(
            NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
            grouping: true)
        )
        .font(.title).fontWeight(.bold)
      case .accessoryRectangular:
        VStack(alignment: .leading) {
          Text(
            hwFormatDecimal(
              NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
              grouping: true)
          )
          .font(.headline).fontWeight(.bold)
          Text(entry.data.scoreLabel ?? "")
            .font(.caption)
        }
      case .accessoryInline:
        Text(
          hwFormatDecimal(
            NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
            grouping: true)
        )
        .font(.body)
      #if compiler(>=6.4)
        case .systemExtraLargePortrait:
          VStack(alignment: .leading) {
            Text("Dashboard")
              .font(.caption)
            Spacer()
            Text(
              hwFormatDecimal(
                NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
                grouping: true)
            )
            .font(.title).fontWeight(.bold)
            Spacer()
            Text(entry.data.scoreLabel ?? "")
              .font(.body).foregroundColor(Color.secondary)
            Spacer()
            Text(
              hwFormatDecimal(
                NSNumber(value: entry.data.streak ?? 0), minFraction: nil, maxFraction: nil,
                grouping: true)
            )
            .font(.caption)
            Spacer()
            Text(entry.data.motivation ?? "")
              .font(.caption).foregroundColor(Color.secondary)
          }
      #endif
      default:
        VStack(alignment: .center) {
          Spacer()
          Text(
            hwFormatDecimal(
              NSNumber(value: entry.data.score ?? 0), minFraction: nil, maxFraction: nil,
              grouping: true)
          )
          .font(.title).fontWeight(.bold)
          Spacer()
        }
      }
    }
    .applyContainerBackground()
  }
}

struct SizeAdaptiveDashboardHomeWidget: Widget {
  let kind: String = "SizeAdaptiveDashboardHomeWidget"

  private var supportedFamilies: [WidgetFamily] {
    var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
    if #available(iOSApplicationExtension 16.0, *) {
      families.append(contentsOf: [.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
    #if compiler(>=6.4)
      if #available(iOSApplicationExtension 27.0, *) {
        families.append(.systemExtraLargePortrait)
      }
    #endif
    return families
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      SizeAdaptiveDashboardHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Size Adaptive Dashboard")
    .supportedFamilies(supportedFamilies)
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

struct SizeAdaptiveDashboardData {
  let score: Int?
  let scoreLabel: String?
  let streak: Int?
  let motivation: String?

  static let paramPrefix = "home_widget.SizeAdaptiveDashboard"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> SizeAdaptiveDashboardData {
    return SizeAdaptiveDashboardData(
      score: (defaults?.object(forKey: "\(paramPrefix).score") as? Int ?? 0),
      scoreLabel: (defaults?.string(forKey: "\(paramPrefix).scoreLabel") ?? "Points"),
      streak: (defaults?.object(forKey: "\(paramPrefix).streak") as? Int ?? 0),
      motivation: (defaults?.string(forKey: "\(paramPrefix).motivation") ?? "Keep it up!"),
    )
  }
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
