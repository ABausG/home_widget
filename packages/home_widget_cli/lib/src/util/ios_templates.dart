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
  String? displayName,
  String? description,
  String? supportedFamilies,
  Set<String>? swiftViewModifiers,
  bool hasCustomContainerBackground = false,
  bool applyContentPadding = true,
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

  final buffer = StringBuffer();
  buffer.writeln(head);
  buffer.writeln('//');
  buffer.writeln('// Placeholder SwiftUI widget.');
  buffer.writeln('//');
  buffer.writeln('// App Group ID used here: $appGroupId');
  buffer.writeln();
  buffer.writeln('import SwiftUI');
  buffer.writeln('import WidgetKit');
  buffer.writeln();
  buffer.writeln('struct Provider: TimelineProvider {');
  buffer.writeln(
    '  func placeholder(in context: Context) -> ${widgetClassName}Entry {',
  );
  buffer.writeln(
    '    ${placeholderBody ?? '${widgetClassName}Entry(date: Date())'}',
  );
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln(
    '  func getSnapshot(in context: Context, completion: @escaping (${widgetClassName}Entry) -> Void) {',
  );
  buffer.writeln(snapshotBody);
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln(
    '  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {',
  );
  buffer.writeln(timelineBody);
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();
  buffer.writeln(entryDef);
  buffer.writeln();
  buffer.writeln('struct ${widgetClassName}EntryView: View {');
  buffer.writeln('  var entry: Provider.Entry');

  if (swiftViewModifiers != null && swiftViewModifiers.isNotEmpty) {
    buffer.writeln();
    for (final modifier in swiftViewModifiers) {
      buffer.writeln('  $modifier');
    }
  }

  buffer.writeln();
  buffer.writeln('  var body: some View {');
  buffer.writeln(viewBody);
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();
  buffer.writeln('struct $widgetClassName: Widget {');
  buffer.writeln('  let kind: String = "$widgetClassName"');
  buffer.writeln();
  buffer.writeln('  var body: some WidgetConfiguration {');
  buffer.writeln(
    '    StaticConfiguration(kind: kind, provider: Provider()) { entry in',
  );
  buffer.writeln('      ${widgetClassName}EntryView(entry: entry)');
  buffer.writeln('    }');
  buffer.writeln(
    '    .configurationDisplayName("${displayName ?? widgetClassName}")',
  );

  if (description != null) {
    buffer.writeln('    .description("$description")');
  }

  if (supportedFamilies != null) {
    buffer.writeln('    .supportedFamilies($supportedFamilies)');
  }

  if (!applyContentPadding) {
    buffer.writeln('    .disableContentMarginsIfNeeded()');
  }

  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();

  final includesContainerBackground =
      entryViewBody?.contains('.applyContainerBackground') ?? false;

  if (includesContainerBackground && !hasCustomContainerBackground) {
    buffer.writeln('''
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
''');
  }

  if (includesContainerBackground && hasCustomContainerBackground) {
    buffer.writeln('''
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
''');
  }

  if (!applyContentPadding) {
    buffer.writeln('''
extension WidgetConfiguration {
  func disableContentMarginsIfNeeded() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 15.0, macOS 12.0, watchOS 9.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}
''');
  }

  buffer.writeln(extraContent ?? '');

  return buffer.toString();
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
