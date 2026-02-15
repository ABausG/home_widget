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
  String? placeholderBody,
  String? entryDefinition,
  String? getSnapshotBody,
  String? getTimelineBody,
  String? entryViewBody,
  String? extraContent,
  String? header,
}) {
  final head = header ?? _defaultHeader;
  final entryDef = entryDefinition ??
      '''
struct ${widgetClassName}Entry: TimelineEntry {
  let date: Date
}
''';
  final snapshotBody = getSnapshotBody ??
      '''
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: "$appGroupId")
    // let counter = prefs?.integer(forKey: "counter") ?? 0
    completion(${widgetClassName}Entry(date: Date()))
''';
  final timelineBody = getTimelineBody ??
      '''
    completion(Timeline(entries: [${widgetClassName}Entry(date: Date())], policy: .atEnd))
''';
  final viewBody = entryViewBody ??
      '''
    Text("$widgetClassName (placeholder)")
''';

  return '''
$head
//
// Placeholder SwiftUI widget.
//
// App Group ID used here: $appGroupId

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ${widgetClassName}Entry {
    ${placeholderBody ?? '${widgetClassName}Entry(date: Date())'}
  }

  func getSnapshot(in context: Context, completion: @escaping (${widgetClassName}Entry) -> Void) {
$snapshotBody
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
$timelineBody
  }
}

$entryDef

struct ${widgetClassName}EntryView: View {
  var entry: Provider.Entry

  var body: some View {
$viewBody
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

${extraContent ?? ''}
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
