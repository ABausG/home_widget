// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: InteractiveCounterHomeWidgetFlavor.appGroupId

import AppIntents
import CoreText
import SwiftUI
import WidgetKit

enum InteractiveCounterHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> InteractiveCounterHomeWidgetEntry {
    InteractiveCounterHomeWidgetEntry(
      date: Date(), data: InteractiveCounterData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (InteractiveCounterHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: InteractiveCounterHomeWidgetFlavor.appGroupId)
    let data = InteractiveCounterData.fromUserDefaults(prefs)

    completion(InteractiveCounterHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: InteractiveCounterHomeWidgetFlavor.appGroupId)
    let data = InteractiveCounterData.fromUserDefaults(prefs)

    completion(
      Timeline(
        entries: [InteractiveCounterHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct InteractiveCounterHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: InteractiveCounterData
}

struct InteractiveCounterHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      Spacer(minLength: 0)
      Text(
        hwFormatDecimal(
          NSNumber(value: entry.data.count ?? 0), minFraction: nil, maxFraction: nil, grouping: true
        )
      )
      .font(.title).fontWeight(.bold)
      HStack(alignment: .center, spacing: 0) {
        hwButton(URL(string: "homewidget://interaction/decrement?homeWidget")) {
          Text(String(UnicodeScalar(UInt32(0xE518))!))
            .font(hwBundledFont("hw_font_icons_materialicons", size: 32))
            .frame(width: 32, height: 32)
            .foregroundColor(Color.primary)
            .accessibilityLabel("Decrement")
        }
        hwButton(
          hwPayloadUrl("homewidget://interaction/increment", [("step", "1")], "homeWidget", "")
        ) {
          Text(String(UnicodeScalar(UInt32(0xE050))!))
            .font(hwBundledFont("hw_font_icons_materialicons", size: 32))
            .frame(width: 32, height: 32)
            .foregroundColor(Color.primary)
            .accessibilityLabel("Increment")
        }
        .padding(.leading, 24.0)
      }
      .padding(.top, 8.0)
      Spacer(minLength: 0)
    }
    .applyContainerBackground()
  }
}

struct InteractiveCounterHomeWidget: Widget {
  let kind: String = "InteractiveCounterHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      InteractiveCounterHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Interactive Counter")
    .description("A counter with buttons that run Dart code in the background.")
    .supportedFamilies([.systemSmall, .systemMedium])
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

struct InteractiveCounterData {
  let count: Int?

  static let paramPrefix = "home_widget.InteractiveCounter"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> InteractiveCounterData {
    return InteractiveCounterData(
      count: (defaults?.object(forKey: "\(paramPrefix).count") as? Int ?? 0),
    )
  }
}

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

struct HWButtonView<Content: View>: View {
  let url: URL?
  let content: Content

  @Environment(\.widgetFamily) private var family

  var body: some View {
    if #available(iOS 17.0, *), let url = url, family != .accessoryInline {
      Button(
        intent: InteractiveCounterHomeWidgetIntent(
          url: url, appGroup: InteractiveCounterHomeWidgetFlavor.appGroupId,
          key: "InteractiveCounterHomeWidget")
      ) {
        content
      }
      .buttonStyle(.plain)
    } else {
      content
    }
  }
}

func hwButton<Content: View>(_ url: URL?, @ViewBuilder content: () -> Content) -> some View {
  return HWButtonView(url: url, content: content())
}
