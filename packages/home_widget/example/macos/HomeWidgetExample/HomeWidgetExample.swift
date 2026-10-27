import AppKit
import Security
import SwiftUI
import WidgetKit

private struct HomeWidgetEntry: TimelineEntry {
  let date: Date
  var name = "Home Widget"
  var image: Data?
  var screenshot: Data?
  var token: String?
  var group: String?
  var counter = 0
}

private struct Provider: TimelineProvider {
  func entry(name: String = "Home Widget") -> HomeWidgetEntry {
    var entry = HomeWidgetEntry(date: Date())
    entry.name = name
    guard let task = SecTaskCreateFromSelf(nil),
      let groups = SecTaskCopyValueForEntitlement(
        task, "com.apple.security.application-groups" as CFString, nil) as? [String],
      let group = groups.first,
      let defaults = UserDefaults(suiteName: group)
    else {
      return entry
    }
    entry.group = group
    entry.counter = defaults.integer(forKey: "example_counter")
    if let path = defaults.string(forKey: "example_image") {
      entry.image = try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    if let path = defaults.string(forKey: "example_screenshot") {
      entry.screenshot = try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    entry.token = defaults.string(forKey: "example_token")
    return entry
  }

  func placeholder(in context: Context) -> HomeWidgetEntry {
    HomeWidgetEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (HomeWidgetEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<HomeWidgetEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .never))
  }
}

private struct HomeWidgetView: View {
  let entry: HomeWidgetEntry

  var body: some View {
    if #available(macOS 14.0, *) {
      content.containerBackground(.fill.tertiary, for: .widget)
    } else {
      content.padding()
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.name).font(.headline).lineLimit(1)
      if let data = entry.image, let image = NSImage(data: data),
        let screenshotData = entry.screenshot, let screenshot = NSImage(data: screenshotData)
      {
        HStack {
          Image(nsImage: image).resizable().scaledToFit()
          Image(nsImage: screenshot).resizable().scaledToFit()
        }
        .frame(height: 60)
        Text(entry.token ?? "").font(.caption2).lineLimit(1)
      } else {
        Image(systemName: "rectangle.3.group").font(.title)
        Text("Ready")
      }
      if #available(macOS 14.0, *), let group = entry.group {
        Button(
          intent: BackgroundIntent(
            url: URL(string: "homewidget-macos://increment"), appGroup: group)
        ) {
          Label("Count: \(entry.counter)", systemImage: "plus")
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .widgetURL(URL(string: "homewidget-macos://widget?homeWidget"))
  }
}

struct HomeWidgetExample: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HomeWidgetMacOSExample", provider: Provider()) { entry in
      HomeWidgetView(entry: entry)
    }
    .configurationDisplayName("HomeWidget macOS")
    .description("Shared data, images, links and background buttons.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@available(macOS 14.0, *)
private struct ConfigurableProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> HomeWidgetEntry {
    HomeWidgetEntry(date: Date())
  }

  func snapshot(for configuration: HomeWidgetConfiguration, in context: Context) async
    -> HomeWidgetEntry
  {
    Provider().entry(name: configuration.name)
  }

  func timeline(for configuration: HomeWidgetConfiguration, in context: Context) async
    -> Timeline<HomeWidgetEntry>
  {
    Timeline(entries: [await snapshot(for: configuration, in: context)], policy: .never)
  }
}

@available(macOS 14.0, *)
struct HomeWidgetConfigurableExample: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: "HomeWidgetMacOSConfigurableExample", intent: HomeWidgetConfiguration.self,
      provider: ConfigurableProvider()
    ) { entry in
      HomeWidgetView(entry: entry)
    }
    .configurationDisplayName("HomeWidget macOS Configurable")
    .description("Edit the name and read it back in Flutter.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct HomeWidgetExampleBundle: WidgetBundle {
  var body: some Widget {
    HomeWidgetExample()
    if #available(macOS 14.0, *) {
      HomeWidgetConfigurableExample()
    }
  }
}
