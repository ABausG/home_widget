// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: StreakHomeWidgetFlavor.appGroupId

import CoreText
import ImageIO
import SwiftUI
import WidgetKit

enum StreakHomeWidgetFlavor {
  static let appGroupId = "group.es.antonborri.streakWidget"
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> StreakHomeWidgetEntry {
    StreakHomeWidgetEntry(date: Date(), data: StreakData.previewFromUserDefaults(nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (StreakHomeWidgetEntry) -> Void) {
    if context.isPreview {
      let prefs: UserDefaults? = nil
      let data = StreakData.previewFromUserDefaults(prefs)
      completion(StreakHomeWidgetEntry(date: Date(), data: data))
      return
    }

    let prefs = UserDefaults(suiteName: StreakHomeWidgetFlavor.appGroupId)
    let data = StreakData.fromUserDefaults(prefs)

    completion(StreakHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: StreakHomeWidgetFlavor.appGroupId)
    let timedEntries = StreakData.loadTimedEntries(prefs)
    let now = Date()
    var entries: [StreakHomeWidgetEntry] = [
      StreakHomeWidgetEntry(
        date: now,
        data: StreakData.fromUserDefaults(prefs, at: now, timedEntries: timedEntries)
      )
    ]
    for timedEntry in timedEntries where timedEntry.date > now {
      entries.append(
        StreakHomeWidgetEntry(
          date: timedEntry.date,
          data: StreakData.fromUserDefaults(prefs, at: timedEntry.date, timedEntries: timedEntries)
        )
      )
    }
    completion(Timeline(entries: entries, policy: .atEnd))

  }
}

struct StreakHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: StreakData
}

struct StreakHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    ZStack(alignment: .topLeading) {
      Group {
        if let path = entry.data.mascot, let uiImage = hwDecodeImage(path, nil, nil) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
            .accessibilityLabel("Dash reacting to your streak")
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      Group {
        if entry.data.frozen == true {
          HStack(alignment: .center, spacing: 0) {
            Text(String(UnicodeScalar(UInt32(0xE037))!))
              .font(hwBundledFont("hw_font_icons_materialicons", size: 24))
              .frame(width: 24, height: 24)
              .foregroundColor(
                Color(
                  red: 0.10980392156862745, green: 0.6901960784313725, blue: 0.9647058823529412,
                  opacity: 0.8784313725490196)
              )
              .accessibilityLabel("Streak frozen")
            Text(
              hwFormatDecimal(
                NSNumber(value: entry.data.streak ?? 0), minFraction: nil, maxFraction: nil,
                grouping: true)
            )
            .font(hwFont("Nunito", 900, false, 28)).foregroundColor(
              Color(
                red: 0.10980392156862745, green: 0.6901960784313725, blue: 0.9647058823529412,
                opacity: 0.8784313725490196)
            )
            .padding(.leading, 2.0)
          }
        } else {
          if entry.data.completed == true {
            HStack(alignment: .center, spacing: 0) {
              Text(String(UnicodeScalar(UInt32(0xE392))!))
                .font(hwBundledFont("hw_font_icons_materialicons", size: 24))
                .frame(width: 24, height: 24)
                .foregroundColor(
                  Color(red: 1.0, green: 0.5882352941176471, blue: 0.0, opacity: 0.8784313725490196)
                )
                .accessibilityLabel("Lesson done")
              Text(
                hwFormatDecimal(
                  NSNumber(value: entry.data.streak ?? 0), minFraction: nil, maxFraction: nil,
                  grouping: true)
              )
              .font(hwFont("Nunito", 900, false, 28)).foregroundColor(
                Color(red: 1.0, green: 0.5882352941176471, blue: 0.0, opacity: 0.8784313725490196)
              )
              .padding(.leading, 2.0)
            }
          } else {
            HStack(alignment: .center, spacing: 0) {
              Text(String(UnicodeScalar(UInt32(0xE392))!))
                .font(hwBundledFont("hw_font_icons_materialicons", size: 24))
                .frame(width: 24, height: 24)
                .foregroundColor(
                  Color(
                    red: 0.6862745098039216, green: 0.6862745098039216, blue: 0.6862745098039216,
                    opacity: 0.8784313725490196)
                )
                .accessibilityLabel("Lesson not done yet")
              Text(
                hwFormatDecimal(
                  NSNumber(value: entry.data.streak ?? 0), minFraction: nil, maxFraction: nil,
                  grouping: true)
              )
              .font(hwFont("Nunito", 900, false, 28)).foregroundColor(
                Color(
                  red: 0.6862745098039216, green: 0.6862745098039216, blue: 0.6862745098039216,
                  opacity: 0.8784313725490196)
              )
              .padding(.leading, 2.0)
            }
          }
        }
      }
      .padding(EdgeInsets(top: 0.0, leading: 6.0, bottom: 0.0, trailing: 10.0))
      .background(
        RoundedRectangle(cornerRadius: 16.0).fill(
          Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.45098039215686275))
      )
      .padding(EdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      Group {
        if entry.data.message != nil {
          Text(entry.data.message ?? "")
            .font(.caption2).fontWeight(.bold).foregroundColor(
              Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.9490196078431372)
            )
            .multilineTextAlignment(.center)
            .padding(EdgeInsets(top: 2.0, leading: 8.0, bottom: 2.0, trailing: 8.0))
            .background(
              RoundedRectangle(cornerRadius: 16.0).fill(
                Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.45098039215686275))
            )
            .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        } else {

        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .clipped()
    .applyContainerBackground()
  }
}

struct StreakHomeWidget: Widget {
  let kind: String = "StreakHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      StreakHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Streak")
    .description("Your Dasholingo streak, with Dash reacting through the day.")
    .supportedFamilies([.systemSmall])
    .disableContentMarginsIfNeeded()
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

extension WidgetConfiguration {
  func disableContentMarginsIfNeeded() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 15.0, macOS 12.0, watchOS 9.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}

struct StreakData {
  let frozen: Bool?
  let streak: Int?
  let completed: Bool?
  let mascot: String?
  let message: String?

  static let paramPrefix = "home_widget.Streak"

  static func fromUserDefaults(
    _ defaults: UserDefaults?,
    at date: Date = Date(),
    timedEntries: [(date: Date, values: [String: Any])]? = nil
  ) -> StreakData {
    let timedValues = activeTimedValues(timedEntries ?? loadTimedEntries(defaults), at: date)
    return StreakData(
      frozen: (defaults?.object(forKey: "\(paramPrefix).frozen") as? Bool ?? false),
      streak: (defaults?.object(forKey: "\(paramPrefix).streak") as? Int ?? 0),
      completed: (defaults?.object(forKey: "\(paramPrefix).completed") as? Bool ?? false),
      mascot: timedValues["mascot"] as? String,
      message: timedValues["message"] as? String,
    )
  }

  static func previewFromUserDefaults(
    _ defaults: UserDefaults?,
    at date: Date = Date(),
    timedEntries: [(date: Date, values: [String: Any])]? = nil
  ) -> StreakData {
    let timedValues = activeTimedValues(timedEntries ?? loadTimedEntries(defaults), at: date)
    return StreakData(
      frozen: (defaults?.object(forKey: "\(paramPrefix).frozen") as? Bool ?? false),
      streak: (defaults?.object(forKey: "\(paramPrefix).streak") as? Int ?? 12),
      completed: (defaults?.object(forKey: "\(paramPrefix).completed") as? Bool ?? true),
      mascot: (timedValues["mascot"] as? String) ?? "assets/dash/success_grass.png",
      message: (timedValues["message"] as? String) ?? "Streak secured",
    )
  }

  fileprivate static func loadTimedEntries(_ defaults: UserDefaults?) -> [(
    date: Date, values: [String: Any]
  )] {
    guard let path = defaults?.string(forKey: "\(paramPrefix).timedData") else { return [] }
    guard FileManager.default.fileExists(atPath: path) else { return [] }
    do {
      let raw = try Data(contentsOf: URL(fileURLWithPath: path))
      guard let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
        return []
      }
      var entries: [(date: Date, values: [String: Any])] = []
      for (key, value) in json {
        guard let millis = Double(key), let values = value as? [String: Any] else { continue }
        entries.append((date: Date(timeIntervalSince1970: millis / 1000), values: values))
      }
      entries.sort { $0.date < $1.date }
      return entries
    } catch {
      return []
    }
  }

  fileprivate static func activeTimedValues(
    _ entries: [(date: Date, values: [String: Any])], at date: Date
  ) -> [String: Any] {
    var values: [String: Any] = [:]
    for entry in entries {
      if entry.date > date { break }
      values = entry.values
    }
    return values
  }
}

func hwDecodeImage(_ path: String, _ widthPt: Double?, _ heightPt: Double?) -> UIImage? {
  func assetFile(_ asset: String) -> String? {
    let appBundleURL = Bundle.main.bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let url =
      appBundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets")
      .appendingPathComponent(asset)
    return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
  }

  guard let file = path.hasPrefix("/") ? path : assetFile(path),
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil)
  else { return nil }
  let displayScale = UITraitCollection.current.displayScale
  let scale = displayScale > 0 ? displayScale : 3
  let fallback = CGFloat(1536)
  let targetWidth = widthPt.map { CGFloat($0) * scale } ?? fallback
  let targetHeight = heightPt.map { CGFloat($0) * scale } ?? fallback
  let maxPixelSize = Int(max(targetWidth, targetHeight).rounded())
  guard maxPixelSize > 0 else { return nil }
  let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceShouldCacheImmediately: true,
    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
  ]
  guard
    let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  else { return nil }
  return UIImage(cgImage: thumbnail, scale: scale, orientation: .up)
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
