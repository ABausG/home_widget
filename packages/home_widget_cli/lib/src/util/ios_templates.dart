const String _defaultHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// Generates the Swift code for the Widget.
///
/// [widgetClassName]: The class name of the widget (e.g., `ExampleWidgetHomeWidget`).
/// [appGroupId]: The App Group ID for data sharing.
/// [widgetBody]: Optional body content for the `Widget` configuration.
///               If null, a placeholder configuration is generated.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String iosWidgetSwiftTemplate({
  required String widgetClassName,
  required String appGroupId,
  String? widgetBody,
  String? header,
}) {
  final head = header ?? _defaultHeader;
  return '''
$head
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: $appGroupId

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: "$appGroupId")
    // let counter = prefs?.integer(forKey: "counter") ?? 0
    completion(SimpleEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .atEnd))
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
}

struct ${widgetClassName}EntryView: View {
  var entry: Provider.Entry
  var body: some View {
    Text("$widgetClassName (placeholder)")
  }
}

struct $widgetClassName: Widget {
  let kind: String = "$widgetClassName"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ${widgetClassName}EntryView(entry: entry)
    }
    .configurationDisplayName("$widgetClassName")
    .description("home_widget placeholder widget")
  }
}
''';
}

/// Generates the Swift code for the WidgetBundle.
///
/// [widgetClassName]: The class name of the main widget.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String iosWidgetBundleSwiftTemplate({
  required String widgetClassName,
  String? header,
}) {
  final head = header ?? _defaultHeader;
  return '''
$head

import WidgetKit
import SwiftUI

@main
struct ${widgetClassName}Bundle: WidgetBundle {
  var body: some Widget {
    $widgetClassName()
  }
}
''';
}

/// Generates the Info.plist content for the Widget Extension.
String iosInfoPlistTemplate() {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
''';
}
