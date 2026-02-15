import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import '../util/logger.dart';
import '../util/entitlements.dart';
import '../util/fs.dart';
import '../util/ios_templates.dart';
import '../util/xcode_pbxproj_patcher.dart';

/// Generates iOS WidgetKit extension files from a [WidgetSpec].
class IosGenerator {
  /// The widget specification to generate code for.
  final WidgetSpec spec;

  /// The root directory of the Flutter project.
  final Directory projectRoot;

  /// Creates a new [IosGenerator].
  IosGenerator({
    required this.spec,
    required this.projectRoot,
  });

  /// Generates the iOS WidgetKit extension files and wires them into the
  /// Xcode project.
  Future<void> generate() async {
    final iosDir = Directory(p.join(projectRoot.path, 'ios'));
    if (!iosDir.existsSync()) {
      logger.warn(
        'Warning: ios/ not found. Skipping iOS generation for ${spec.data.name}.',
      );
      return;
    }

    final xcodeproj = File(
      p.join(iosDir.path, 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (!xcodeproj.existsSync()) {
      logger.warn(
        'Warning: ios/Runner.xcodeproj/project.pbxproj not found. '
        'Skipping iOS Widget Extension target wiring.',
      );
    }

    if (spec.data.iOS == null) {
      return;
    }

    final widgetClassName = '${spec.className}HomeWidget';
    final groupId = spec.data.iOS!.groupId;

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

    // 1. Generate Widget.swift
    String? extraContent;
    String? entryDefinition;
    String? getSnapshotBody;
    String? getTimelineBody;
    String? entryViewBody;

    if (spec.dataFields.isNotEmpty) {
      final className = '${spec.className}Data';

      final buffer = StringBuffer();
      buffer.writeln('struct $className {');
      for (final field in spec.dataFields) {
        final type = field.type.swiftType;
        buffer.writeln('  let ${field.key}: $type?');
      }
      buffer.writeln();
      buffer.writeln(
        '  static func fromUserDefaults(_ defaults: UserDefaults?) -> $className {',
      );
      buffer.writeln('    return $className(');
      for (final field in spec.dataFields) {
        final key = field.key;
        String readLogic;
        switch (field.type) {
          case HWDataFieldType.string:
            readLogic = 'defaults?.string(forKey: "$key")';
            break;
          case HWDataFieldType.int_:
            readLogic = 'defaults?.object(forKey: "$key") as? Int';
            break;
          case HWDataFieldType.double_:
            readLogic = 'defaults?.object(forKey: "$key") as? Double';
            break;
          case HWDataFieldType.bool_:
            readLogic = 'defaults?.object(forKey: "$key") as? Bool';
            break;
        }
        buffer.writeln('      ${field.key}: $readLogic,');
      }
      buffer.writeln('    )');
      buffer.writeln('  }');
      buffer.writeln('}');
      extraContent = buffer.toString();

      entryDefinition = '''
struct SimpleEntry: TimelineEntry {
  let date: Date
  let data: $className
}
''';

      final loadDataLogic = '''
    let prefs = UserDefaults(suiteName: "$groupId")
    let data = $className.fromUserDefaults(prefs)
''';
      getSnapshotBody = '''
$loadDataLogic
    completion(SimpleEntry(date: Date(), data: data))
''';
      getTimelineBody = '''
$loadDataLogic
    completion(Timeline(entries: [SimpleEntry(date: Date(), data: data)], policy: .atEnd))
''';

      final viewBuffer = StringBuffer();
      viewBuffer.writeln('    VStack {');
      viewBuffer.writeln('      Text("$widgetClassName")');
      for (final field in spec.dataFields) {
        viewBuffer.writeln(
          '      Text("${field.key}: \\(entry.data.${field.key}?.description ?? "-")")',
        );
      }
      viewBuffer.writeln('    }');
      entryViewBody = viewBuffer.toString();
    }

    await widgetSwift.writeAsString(
      iosWidgetSwiftTemplate(
        widgetClassName: widgetClassName,
        appGroupId: groupId,
        extraContent: extraContent,
        entryDefinition: entryDefinition,
        getSnapshotBody: getSnapshotBody,
        getTimelineBody: getTimelineBody,
        entryViewBody: entryViewBody,
      ),
    );
    logger.success('Generated: ${widgetSwift.path}');

    // 2. Generate WidgetBundle.swift
    await widgetBundleSwift.writeAsString(
      iosWidgetBundleSwiftTemplate(widgetClassName: widgetClassName),
    );
    logger.success('Generated: ${widgetBundleSwift.path}');

    // 3. Generate Info.plist
    await infoPlist.writeAsString(iosInfoPlistTemplate());
    logger.success('Generated: ${infoPlist.path}');

    // 4. Ensure App Group entitlement is present for the extension and Runner.
    await ensureAppGroupEntitlement(
      entitlementsFile: extensionEntitlements,
      appGroupId: groupId,
    );
    logger.success('Updated: ${extensionEntitlements.path}');

    final runnerEntitlements = File(
      p.join(iosDir.path, 'Runner', 'Runner.entitlements'),
    );
    // Flutter templates usually have this file; if not, we still create it.
    await ensureAppGroupEntitlement(
      entitlementsFile: runnerEntitlements,
      appGroupId: groupId,
    );
    logger.success('Updated: ${runnerEntitlements.path}');

    // 5. Patch the Xcode project so the extension can actually be built.
    if (xcodeproj.existsSync()) {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: xcodeproj,
        widgetClassName: widgetClassName,
      );

      // Ensure Runner is signed with Runner/Runner.entitlements (App Groups apply).
      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: xcodeproj);

      // Ensure Runner's deployment target is at least 14.0 (required by home_widget).
      await ensureMinimumDeploymentTargetInXcodeProject(pbxprojFile: xcodeproj);
      logger.success('Updated: ${xcodeproj.path}');
    }
  }
}
