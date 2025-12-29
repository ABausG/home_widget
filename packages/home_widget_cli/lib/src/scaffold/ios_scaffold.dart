import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/fs.dart';

final class IosWidgetScaffold {
  IosWidgetScaffold({required this.projectRoot, required this.widgetClassName});

  final Directory projectRoot;
  final String widgetClassName;

  /// Create iOS widget-extension placeholders.
  Future<void> run({required String appGroupId}) async {
    final iosDir = Directory(p.join(projectRoot.path, 'ios'));
    if (!iosDir.existsSync()) {
      stderr.writeln('Warning: ios/ not found. Skipping iOS scaffolding.');
      return;
    }

    // We only create a folder that could later be added as a Widget Extension
    // target in Xcode.
    final extensionDir = Directory(p.join(iosDir.path, widgetClassName));
    await ensureDir(extensionDir);

    final widgetSwift = File(p.join(extensionDir.path, 'Widget.swift'));
    final widgetBundleSwift = File(
      p.join(extensionDir.path, 'WidgetBundle.swift'),
    );
    final infoPlist = File(p.join(extensionDir.path, 'Info.plist'));

    await writeFileIfMissing(
      widgetSwift,
      _iosWidgetSwiftPlaceholder(widgetClassName, appGroupId: appGroupId),
    );
    await writeFileIfMissing(
      widgetBundleSwift,
      _iosWidgetBundleSwiftPlaceholder(widgetClassName),
    );
    await writeFileIfMissing(
      infoPlist,
      _iosInfoPlistPlaceholder(widgetClassName),
    );
  }
}

String _iosWidgetSwiftPlaceholder(
  String widgetClassName, {
  required String appGroupId,
}) {
  return '''
// GENERATED PLACEHOLDER by home_widget_cli
//
// This file is a placeholder SwiftUI widget. Add this folder as a Widget
// Extension target in Xcode and wire up App Groups + home_widget data reading.
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

String _iosWidgetBundleSwiftPlaceholder(String widgetClassName) {
  return '''
// GENERATED PLACEHOLDER by home_widget_cli

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

String _iosInfoPlistPlaceholder(String widgetClassName) {
  // Minimal placeholder, not a complete extension plist.
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$widgetClassName</string>
</dict>
</plist>
''';
}
