// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: ThemedCounterHomeWidgetFlavor.appGroupId

import CoreText
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
      HStack(alignment: .center, spacing: 0) {
        Spacer(minLength: 0)
        if let codePoint = hwAppearance(hwEnvironment, light: 0xE37A, dark: 0xE1B0),
          let value = UInt32(exactly: codePoint), let scalar = UnicodeScalar(value)
        {
          Text(String(scalar))
            .font(hwBundledFont("hw_font_icons_materialicons", size: 14))
            .frame(width: 14, height: 14)
            .foregroundColor(Color.secondary)
            .accessibilityHidden(true)
        }
        Group {
          if hwIsAccented(hwEnvironment) {
            Text(verbatim: "Tinted / Clear")
              .font(.caption).foregroundColor(Color.secondary)
          } else if hwEnvironment.colorScheme == .dark {
            Text(verbatim: "Dark mode")
              .font(.caption).foregroundColor(Color.secondary)
          } else {
            Text(verbatim: "Light mode")
              .font(.caption).foregroundColor(Color.secondary)
          }
        }
        .padding(.leading, 4.0)
        Spacer(minLength: 0)
      }
      Text(
        hwFormatDecimal(
          NSNumber(value: entry.data.count ?? 0), minFraction: nil, maxFraction: nil, grouping: true
        )
      )
      .font(.title).fontWeight(.bold).foregroundColor(
        hwAppearance(
          hwEnvironment, light: hwColor(entry.data.accentLight),
          dark: hwColor(entry.data.accentDark))
      )
      .padding(.top, 4.0)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .applyContainerBackground(
      (hwAppearance(
        hwEnvironment,
        light: Color(red: 0.9372549019607843, green: 0.9647058823529412, blue: 1.0, opacity: 1.0),
        dark: Color(
          red: 0.043137254901960784, green: 0.07058823529411765, blue: 0.12549019607843137,
          opacity: 1.0))
        ?? Color(red: 0.9372549019607843, green: 0.9647058823529412, blue: 1.0, opacity: 1.0)))
  }
}

struct ThemedCounterHomeWidget: Widget {
  let kind: String = "ThemedCounterHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ThemedCounterHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Themed Counter")
    .description("A counter in an accent color the app picks, themed per appearance.")
    .supportedFamilies([.systemSmall])
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

struct ThemedCounterData {
  let count: Int?
  let accentLight: Int?
  let accentDark: Int?

  static let paramPrefix = "home_widget.ThemedCounter"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> ThemedCounterData {
    return ThemedCounterData(
      count: (defaults?.object(forKey: "\(paramPrefix).count") as? Int ?? 0),
      accentLight: (defaults?.object(forKey: "\(paramPrefix).accentLight") as? Int ?? 0xFF1D_4ED8),
      accentDark: (defaults?.object(forKey: "\(paramPrefix).accentDark") as? Int ?? 0xFF93_C5FD),
    )
  }
}

func hwColor(_ argb: Int?) -> Color? {
  guard let argb else { return nil }
  let value = UInt32(truncatingIfNeeded: argb)
  return Color(
    .sRGB,
    red: Double((value >> 16) & 0xFF) / 255,
    green: Double((value >> 8) & 0xFF) / 255,
    blue: Double(value & 0xFF) / 255,
    opacity: Double((value >> 24) & 0xFF) / 255)
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
