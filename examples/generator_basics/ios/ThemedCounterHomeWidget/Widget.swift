// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: ThemedCounterHomeWidgetFlavor.appGroupId

import SwiftUI
import WidgetKit

enum ThemedCounterHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ThemedCounterHomeWidgetEntry {
    ThemedCounterHomeWidgetEntry(date: Date(), data: ThemedCounterData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (ThemedCounterHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: ThemedCounterHomeWidgetFlavor.appGroupId)
    let data = ThemedCounterData.fromUserDefaults(prefs)

    completion(ThemedCounterHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: ThemedCounterHomeWidgetFlavor.appGroupId)
    let data = ThemedCounterData.fromUserDefaults(prefs)

    completion(
      Timeline(entries: [ThemedCounterHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct ThemedCounterHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: ThemedCounterData
}

struct ThemedCounterHomeWidgetEntryView: View {
  var entry: Provider.Entry

  @Environment(\.self) var hwEnvironment

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      Spacer(minLength: 0)
      Text(verbatim: "Counter")
        .font(.caption).foregroundColor(Color.secondary)
      Text(
        hwFormatDecimal(
          NSNumber(value: entry.data.count ?? 0), minFraction: nil, maxFraction: nil, grouping: true
        )
      )
      .font(.title).fontWeight(.bold).foregroundColor(Color.primary)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .applyContainerBackground(
      optional: hwAppearance(
        hwEnvironment,
        light: Color(red: 0.9372549019607843, green: 0.9647058823529412, blue: 1.0, opacity: 1.0),
        dark: Color(
          red: 0.043137254901960784, green: 0.07058823529411765, blue: 0.12549019607843137,
          opacity: 1.0)))
  }
}

struct ThemedCounterHomeWidget: Widget {
  let kind: String = "ThemedCounterHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ThemedCounterHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Themed Counter")
    .description("A counter with a themed background and role-based colors.")
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

extension View {
  @ViewBuilder
  func applyContainerBackground<T: View>(_ backgroundView: T) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) { backgroundView }
    } else {
      self.background(backgroundView)
    }
  }
}

extension View {
  @ViewBuilder
  func applyContainerBackground(optional backgroundColor: Color?) -> some View {
    if let backgroundColor {
      self.applyContainerBackground(backgroundColor)
    } else {
      self.applyContainerBackground()
    }
  }
}

struct ThemedCounterData {
  let count: Int?

  static let paramPrefix = "home_widget.ThemedCounter"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> ThemedCounterData {
    return ThemedCounterData(
      count: (defaults?.object(forKey: "\(paramPrefix).count") as? Int ?? 0),
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

func hwIsAccented(_ environment: EnvironmentValues) -> Bool {
  if #available(iOS 16.0, *) {
    return environment.widgetRenderingMode == .accented
  }
  return false
}

func hwIsVibrant(_ environment: EnvironmentValues) -> Bool {
  if #available(iOS 16.0, *) {
    return environment.widgetRenderingMode == .vibrant
  }
  return false
}

func hwAppearance<T>(
  _ environment: EnvironmentValues,
  light: @autoclosure () -> T?,
  dark: @autoclosure () -> T?,
  accented: @autoclosure () -> T? = nil,
  vibrant: @autoclosure () -> T? = nil
) -> T? {
  if hwIsAccented(environment), let value = accented() { return value }
  if hwIsVibrant(environment), let value = vibrant() { return value }
  if environment.colorScheme == .dark { return dark() ?? light() }
  return light() ?? dark()
}
