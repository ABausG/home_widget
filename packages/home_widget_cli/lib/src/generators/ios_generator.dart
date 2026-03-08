import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import '../models/extensions.dart';
import '../util/logger.dart';
import '../util/entitlements.dart';
import '../util/fs.dart';
import '../util/ios_templates.dart';
import '../util/xcode_pbxproj_patcher.dart';
import 'swift_widget_emitter.dart';

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
        '  static let paramPrefix = "home_widget.${spec.className}"',
      );
      buffer.writeln();
      buffer.writeln(
        '  static func fromUserDefaults(_ defaults: UserDefaults?) -> $className {',
      );
      buffer.writeln('    return $className(');
      for (final field in spec.dataFields) {
        final readLogic = field.type.iosReadValue(
          store: 'defaults',
          key: '\\(paramPrefix).${field.key}',
        );
        buffer.writeln('      ${field.key}: $readLogic,');
      }
      buffer.writeln('    )');
      buffer.writeln('  }');
      buffer.writeln('}');
      extraContent = buffer.toString();

      entryDefinition = '''
struct ${widgetClassName}Entry: TimelineEntry {
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
    completion(${widgetClassName}Entry(date: Date(), data: data))
''';
      getTimelineBody = '''
$loadDataLogic
    completion(Timeline(entries: [${widgetClassName}Entry(date: Date(), data: data)], policy: .atEnd))
''';

      if (spec.widgetTree == null || spec.widgetTree is HWDataOnly) {
        final viewBuffer = StringBuffer();
        viewBuffer.writeln('    VStack {');
        viewBuffer.writeln('      Text("${spec.data.name}")');
        for (final field in spec.dataFields) {
          viewBuffer.writeln(
            '      Text("${field.key}: \\(entry.data.${field.key}?.description ?? "-")")',
          );
        }
        viewBuffer.writeln('    }');
        viewBuffer.writeln('    .applyContainerBackground()');
        entryViewBody = viewBuffer.toString();
      }
    }

    if (spec.widgetTree != null && spec.widgetTree is! HWDataOnly) {
      final treeCode = emitSwiftWidgetBody(
        spec.widgetTree!,
        dataExpr: 'entry.data',
        indent: 2,
      );
      entryViewBody = '$treeCode\n    .applyContainerBackground()';
    }

    String? supportedFamilies;
    if (spec.data.iOS?.supportedFamilies != null &&
        spec.data.iOS!.supportedFamilies!.isNotEmpty) {
      final families = spec.data.iOS!.supportedFamilies!
          .map((f) => f.toSwiftValue())
          .join(', ');
      supportedFamilies = '[$families]';
    }

    await widgetSwift.writeAsString(
      iosWidgetSwiftTemplate(
        widgetClassName: widgetClassName,
        appGroupId: groupId,
        placeholderBody: spec.dataFields.isNotEmpty
            ? '${widgetClassName}Entry(date: Date(), data: ${spec.className}Data.fromUserDefaults(nil))'
            : null,
        extraContent: extraContent,
        entryDefinition: entryDefinition,
        getSnapshotBody: getSnapshotBody,
        getTimelineBody: getTimelineBody,
        entryViewBody: entryViewBody,
        displayName: spec.data.name,
        description: spec.data.description,
        supportedFamilies: supportedFamilies,
        swiftViewModifiers: spec.widgetTree?.swiftViewModifiers,
      ),
    );
    logger.success('Generated: ${widgetSwift.path}');

    await widgetBundleSwift.writeAsString(
      iosWidgetBundleSwiftTemplate(widgetClassName: widgetClassName),
    );
    logger.success('Generated: ${widgetBundleSwift.path}');

    await infoPlist.writeAsString(iosInfoPlistTemplate());
    logger.success('Generated: ${infoPlist.path}');

    await ensureAppGroupEntitlement(
      entitlementsFile: extensionEntitlements,
      appGroupId: groupId,
    );
    logger.success('Updated: ${extensionEntitlements.path}');

    final runnerEntitlements = File(
      p.join(iosDir.path, 'Runner', 'Runner.entitlements'),
    );

    await ensureAppGroupEntitlement(
      entitlementsFile: runnerEntitlements,
      appGroupId: groupId,
    );
    logger.success('Updated: ${runnerEntitlements.path}');

    if (xcodeproj.existsSync()) {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: xcodeproj,
        widgetClassName: widgetClassName,
      );

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: xcodeproj);
      await ensureMinimumDeploymentTargetInXcodeProject(pbxprojFile: xcodeproj);
      logger.success('Updated: ${xcodeproj.path}');
    }
  }
}
