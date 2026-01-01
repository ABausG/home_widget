import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/cli_io.dart';
import '../util/entitlements.dart';
import '../util/fs.dart';
import '../util/xcode_pbxproj_patcher.dart';

final class IosWidgetScaffold {
  IosWidgetScaffold({required this.projectRoot, required this.widgetClassName});

  final Directory projectRoot;
  final String widgetClassName;

  /// Create iOS widget-extension placeholders.
  Future<void> run({required String appGroupId}) async {
    final iosDir = Directory(p.join(projectRoot.path, 'ios'));
    if (!iosDir.existsSync()) {
      cliIO.writelnErr('Warning: ios/ not found. Skipping iOS scaffolding.');
      return;
    }

    final xcodeproj = File(
      p.join(iosDir.path, 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (!xcodeproj.existsSync()) {
      cliIO.writelnErr(
        'Warning: ios/Runner.xcodeproj/project.pbxproj not found. '
        'Skipping iOS Widget Extension target wiring.',
      );
    }

    // Create the Widget Extension folder and files.
    final extensionDir = Directory(p.join(iosDir.path, widgetClassName));
    await ensureDir(extensionDir);

    final widgetSwift = File(p.join(extensionDir.path, 'Widget.swift'));
    final widgetBundleSwift = File(
      p.join(extensionDir.path, 'WidgetBundle.swift'),
    );
    final infoPlist = File(p.join(extensionDir.path, 'Info.plist'));
    final extensionEntitlements = File(
      p.join(iosDir.path, '$widgetClassName.entitlements'),
    );

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
      _iosInfoPlistPlaceholder(),
    );

    // Ensure App Group entitlement is present for the extension and Runner.
    await ensureAppGroupEntitlement(
      entitlementsFile: extensionEntitlements,
      appGroupId: appGroupId.trim().isEmpty ? 'YOUR_APP_GROUP_ID' : appGroupId,
    );

    final runnerEntitlements = File(
      p.join(iosDir.path, 'Runner', 'Runner.entitlements'),
    );
    // Flutter templates usually have this file; if not, we still create it.
    await ensureAppGroupEntitlement(
      entitlementsFile: runnerEntitlements,
      appGroupId: appGroupId.trim().isEmpty ? 'YOUR_APP_GROUP_ID' : appGroupId,
    );

    // Patch the Xcode project so the extension can actually be built.
    if (xcodeproj.existsSync()) {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: xcodeproj,
        widgetClassName: widgetClassName,
      );

      // Ensure Runner is signed with Runner/Runner.entitlements (App Groups apply).
      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: xcodeproj);
    }
  }
}

String _iosWidgetSwiftPlaceholder(
  String widgetClassName, {
  required String appGroupId,
}) {
  return '''
// GENERATED PLACEHOLDER by home_widget_cli
//
// This file is a placeholder SwiftUI widget. The CLI also wires up a Widget
// Extension target in `ios/Runner.xcodeproj` so you can build right away.
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

String _iosInfoPlistPlaceholder() {
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
