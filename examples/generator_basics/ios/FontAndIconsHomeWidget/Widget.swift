// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: FontAndIconsHomeWidgetFlavor.appGroupId

import CoreText
import SwiftUI
import WidgetKit

enum FontAndIconsHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.generatorBasics"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> FontAndIconsHomeWidgetEntry {
    FontAndIconsHomeWidgetEntry(date: Date(), data: FontAndIconsData.previewFromUserDefaults(nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (FontAndIconsHomeWidgetEntry) -> Void)
  {
    if context.isPreview {
      let prefs: UserDefaults? = UserDefaults(suiteName: FontAndIconsHomeWidgetFlavor.appGroupId)
      let data = FontAndIconsData.previewFromUserDefaults(prefs)
      completion(FontAndIconsHomeWidgetEntry(date: Date(), data: data))
      return
    }

    let prefs = UserDefaults(suiteName: FontAndIconsHomeWidgetFlavor.appGroupId)
    let data = FontAndIconsData.fromUserDefaults(prefs)

    completion(FontAndIconsHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: FontAndIconsHomeWidgetFlavor.appGroupId)
    let data = FontAndIconsData.fromUserDefaults(prefs)

    completion(
      Timeline(entries: [FontAndIconsHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))

  }
}

struct FontAndIconsHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: FontAndIconsData
}

struct FontAndIconsHomeWidgetEntryView: View {
  var entry: Provider.Entry

  @Environment(\.layoutDirection) var layoutDirection

  var body: some View {
    VStack(alignment: .center) {
      Spacer()
      Text("Chewy")
        .font(hwFont("Chewy", 400, false, 24))
      HStack(alignment: .center) {
        Spacer()
        Text(String(UnicodeScalar(UInt32(0xE25B))!))
          .font(hwBundledFont("hw_font_icons_materialicons", size: 24))
          .frame(width: 24, height: 24)
          .foregroundColor(
            Color(
              red: 0.8980392156862745, green: 0.2235294117647059, blue: 0.20784313725490197,
              opacity: 1.0)
          )
          .accessibilityHidden(true)
        Text(String(UnicodeScalar(UInt32(0xF4B6))!))
          .font(hwBundledFont("hw_font_icons_cupertinoicons__cupertino_icons", size: 24))
          .frame(width: 24, height: 24)
          .foregroundColor(
            Color(red: 0.984313725490196, green: 0.5490196078431373, blue: 0.0, opacity: 1.0)
          )
          .accessibilityHidden(true)
        Text(String(UnicodeScalar(UInt32(0xF004))!))
          .font(hwBundledFont("hw_font_icons_fontawesomesolid__font_awesome_flutter", size: 24))
          .frame(width: 24, height: 24)
          .foregroundColor(
            Color(
              red: 0.5568627450980392, green: 0.1411764705882353, blue: 0.6666666666666666,
              opacity: 1.0)
          )
          .accessibilityHidden(true)
        Spacer()
      }
      Text("three icons, three fonts")
        .font(.caption)
      if let codePoint = entry.data.mood, let value = UInt32(exactly: codePoint),
        let scalar = UnicodeScalar(value)
      {
        Text(String(scalar))
          .font(hwBundledFont("hw_font_icons_materialicons", size: 40))
          .frame(width: 40, height: 40)
          .foregroundColor(Color.primary)
          .accessibilityLabel("Mood")
          .scaleEffect(
            x: layoutDirection == .rightToLeft && hwMirroredIcons.contains(codePoint) ? -1 : 1, y: 1
          )
      }
      Spacer()
    }
    .applyContainerBackground()
  }
}

struct FontAndIconsHomeWidget: Widget {
  let kind: String = "FontAndIconsHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      FontAndIconsHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Font & Icons")
    .description("Text in a bundled font next to fixed and data-bound icons.")
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

struct FontAndIconsData {
  let mood: Int?

  static let paramPrefix = "home_widget.FontAndIcons"

  static func fromUserDefaults(_ defaults: UserDefaults?) -> FontAndIconsData {
    return FontAndIconsData(
      mood: (defaults?.object(forKey: "\(paramPrefix).mood") as? Int ?? 59097),
    )
  }

  static func previewFromUserDefaults(_ defaults: UserDefaults?) -> FontAndIconsData {
    return FontAndIconsData(
      mood: (defaults?.object(forKey: "\(paramPrefix).mood") as? Int ?? 58873),
    )
  }
}

private let hwMirroredIcons: Set<Int> = [0xE09B]

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

func hwAssetFont(_ asset: String, _ size: CGFloat) -> Font {
  let font = HWFontCache.shared.font("asset:" + asset, size) { () -> Font? in
    let url = Bundle.main.bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Frameworks/App.framework/flutter_assets")
      .appendingPathComponent(asset)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return hwFontFromURL(url, size)
  }
  return font ?? .system(size: size)
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

private final class HWFontManifest: @unchecked Sendable {
  struct Variant {
    let asset: String
    let weight: Int
    let italic: Bool
  }

  static let shared = HWFontManifest()

  private let lock = NSLock()
  private var families: [String: [Variant]]?

  func variants(of family: String) -> [Variant] {
    lock.lock()
    defer { lock.unlock() }
    if families == nil { families = HWFontManifest.read() }
    return families?[family] ?? []
  }

  private static func read() -> [String: [Variant]] {
    let url = Bundle.main.bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Frameworks/App.framework/flutter_assets")
      .appendingPathComponent("FontManifest.json")
    guard let data = try? Data(contentsOf: url),
      let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [:] }

    var families: [String: [Variant]] = [:]
    for entry in entries {
      guard let family = entry["family"] as? String,
        let fonts = entry["fonts"] as? [[String: Any]]
      else { continue }
      let variants = fonts.compactMap { font -> Variant? in
        guard let asset = font["asset"] as? String else { return nil }
        return Variant(
          asset: asset,
          weight: font["weight"] as? Int ?? 400,
          italic: font["style"] as? String == "italic")
      }
      if !variants.isEmpty { families[family] = variants }
    }
    return families
  }
}

func hwFont(_ family: String, _ weight: Int, _ italic: Bool, _ size: CGFloat) -> Font {
  let variants = HWFontManifest.shared.variants(of: family)
  let matchingStyle = variants.filter { $0.italic == italic }
  let pool = matchingStyle.isEmpty ? variants : matchingStyle
  if let exact = pool.first(where: { $0.weight == weight }) {
    return hwAssetFont(exact.asset, size)
  }
  let lighter = pool.filter { $0.weight < weight }.sorted { $0.weight > $1.weight }
  let heavier = pool.filter { $0.weight > weight }.sorted { $0.weight < $1.weight }
  guard let nearest = (weight <= 400 ? lighter + heavier : heavier + lighter).first
  else { return .system(size: size) }
  return hwAssetFont(nearest.asset, size)
}
