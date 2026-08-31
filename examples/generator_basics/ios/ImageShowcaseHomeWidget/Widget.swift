// GENERATED CODE - DO NOT MODIFY BY HAND
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: group.es.antonborri.generatorBasics

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ImageShowcaseHomeWidgetEntry {
    ImageShowcaseHomeWidgetEntry(date: Date(), data: ImageShowcaseData.fromUserDefaults(nil))
  }

  func getSnapshot(
    in context: Context, completion: @escaping (ImageShowcaseHomeWidgetEntry) -> Void
  ) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let data = ImageShowcaseData.fromUserDefaults(prefs)

    completion(ImageShowcaseHomeWidgetEntry(date: Date(), data: data))

  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let prefs = UserDefaults(suiteName: "group.es.antonborri.generatorBasics")
    let timedEntries = ImageShowcaseData.loadTimedEntries(prefs)
    let now = Date()
    var entries: [ImageShowcaseHomeWidgetEntry] = [
      ImageShowcaseHomeWidgetEntry(
        date: now,
        data: ImageShowcaseData.fromUserDefaults(prefs, at: now, timedEntries: timedEntries)
      )
    ]
    for timedEntry in timedEntries where timedEntry.date > now {
      entries.append(
        ImageShowcaseHomeWidgetEntry(
          date: timedEntry.date,
          data: ImageShowcaseData.fromUserDefaults(
            prefs, at: timedEntry.date, timedEntries: timedEntries)
        )
      )
    }
    completion(Timeline(entries: entries, policy: .atEnd))

  }
}

struct ImageShowcaseHomeWidgetEntry: TimelineEntry {
  let date: Date
  let data: ImageShowcaseData
}

struct ImageShowcaseHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .center) {
      Spacer()
      if let path = flutterAssetPath("assets/logo.png"), let uiImage = UIImage(contentsOfFile: path)
      {
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 24.0, height: 24.0)
          .accessibilityLabel("App logo")
      }
      if let hwImagePath = entry.data.picture, FileManager.default.fileExists(atPath: hwImagePath) {
        if let path = entry.data.picture, let uiImage = UIImage(contentsOfFile: path) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 64.0, height: 64.0)
            .clipped()
            .accessibilityLabel("Picture saved by the app")
        }
      } else {
        Text("Open the app to pick an image")
          .font(.caption).foregroundColor(Color.secondary)
      }
      HStack(alignment: .center) {
        Spacer()
        if let path = entry.data.slide, let uiImage = UIImage(contentsOfFile: path) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28.0, height: 28.0)
            .accessibilityLabel("Picture for the current time slot")
        }
        if let path = entry.data.contact?.avatar, let uiImage = UIImage(contentsOfFile: path) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 28.0, height: 28.0)
            .clipped()
            .accessibilityLabel("Contact avatar")
        }
        Text((((entry.data.contact?.name) ?? (""))) ?? "")
          .font(.caption)
        Spacer()
      }
      Spacer()
    }
    .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .applyContainerBackground()
  }
}

struct ImageShowcaseHomeWidget: Widget {
  let kind: String = "ImageShowcaseHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ImageShowcaseHomeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Image Showcase")
    .description("A bundled asset logo plus images saved by the app.")
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

struct ImageShowcaseData {
  let picture: String?
  let contact: ImageShowcaseContactJsonData?
  let slide: String?

  static let paramPrefix = "home_widget.ImageShowcase"

  static func fromUserDefaults(
    _ defaults: UserDefaults?,
    at date: Date = Date(),
    timedEntries: [(date: Date, values: [String: Any])]? = nil
  ) -> ImageShowcaseData {
    let timedValues = activeTimedValues(timedEntries ?? loadTimedEntries(defaults), at: date)
    return ImageShowcaseData(
      picture: defaults?.string(forKey: "\(paramPrefix).picture"),
      contact: ImageShowcaseContactJsonData.fromPath(
        defaults?.string(forKey: "\(paramPrefix).contact")),
      slide: timedValues["slide"] as? String,
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

struct ImageShowcaseContactJsonData {
  let avatar: String?
  let name: String

  static func fromPath(_ path: String?) -> ImageShowcaseContactJsonData? {
    guard let path else { return nil }
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
      }
      return fromJson(json)
    } catch {
      return nil
    }
  }

  static func fromJson(_ json: [String: Any]?) -> ImageShowcaseContactJsonData? {
    guard let values = json else { return nil }
    return ImageShowcaseContactJsonData(
      avatar: (values["avatar"] as? String) ?? nil,
      name: (values["name"] as? String) ?? "",
    )
  }
}

private func flutterAssetPath(_ asset: String) -> String? {
  let appBundleURL = Bundle.main.bundleURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let url =
    appBundleURL
    .appendingPathComponent("Frameworks/App.framework/flutter_assets")
    .appendingPathComponent(asset)
  return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
}
