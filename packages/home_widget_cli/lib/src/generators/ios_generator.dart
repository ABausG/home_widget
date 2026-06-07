import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import '../models/extensions.dart';
import '../util/logger.dart';
import '../util/entitlements.dart';
import '../util/fs.dart';
import '../util/ios_templates.dart';
import '../util/naming.dart';
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
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final hasDataFields = primitiveFields.isNotEmpty || jsonGroups.isNotEmpty;

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

    if (hasDataFields) {
      final className = '${spec.className}Data';

      final buffer = StringBuffer();
      buffer.writeln('struct $className {');
      for (final field in primitiveFields) {
        final type = field.swiftType;
        buffer.writeln('  let ${field.key}: $type?');
      }
      for (final group in jsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln('  let ${group.key}: $jsonClass?');
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
      for (final field in primitiveFields) {
        final readLogic = field.iosReadValue(
          store: 'defaults',
          key: '\\(paramPrefix).${field.key}',
        );
        buffer.writeln('      ${field.key}: $readLogic,');
      }
      for (final group in jsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln(
          '      ${group.key}: $jsonClass.fromPath(defaults?.string(forKey: "\\(paramPrefix).${group.key}")),',
        );
      }
      buffer.writeln('    )');
      buffer.writeln('  }');
      buffer.writeln('}');
      for (final group in jsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln();
        final tree = _buildJsonTree(group.children);
        _writeSwiftJsonNodeStruct(
          buffer: buffer,
          structName: jsonClass,
          node: tree,
          isRoot: true,
        );
      }
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
    }

    final treeCode = emitSwiftWidgetBody(
      spec.effectiveWidgetTree,
      dataExpr: 'entry.data',
      indent: 2,
    );

    final customBgColor = spec.data.iOS?.backgroundColor;
    final applyPadding = spec.data.iOS?.applyContentPadding ?? true;
    final dataExpr = hasDataFields ? 'entry.data' : 'null';
    final hasCustomBg = customBgColor != null;
    final containerBackgroundModifier = hasCustomBg
        ? '.applyContainerBackground(${customBgColor.toSwift(2, dataExpr: dataExpr)})'
        : '.applyContainerBackground()';
    entryViewBody = '$treeCode\n    $containerBackgroundModifier';

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
        placeholderBody: hasDataFields
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
        swiftViewModifiers: {
          ...spec.effectiveWidgetTree.swiftViewModifiers,
          if (customBgColor != null) ...customBgColor.swiftViewModifiers,
        },
        hasCustomContainerBackground: hasCustomBg,
        applyContentPadding: applyPadding,
      ),
    );
    logger.detail('Generated: ${widgetSwift.path}');

    await widgetBundleSwift.writeAsString(
      iosWidgetBundleSwiftTemplate(widgetClassName: widgetClassName),
    );
    logger.detail('Generated: ${widgetBundleSwift.path}');

    await infoPlist.writeAsString(iosInfoPlistTemplate());
    logger.detail('Generated: ${infoPlist.path}');

    await ensureAppGroupEntitlement(
      entitlementsFile: extensionEntitlements,
      appGroupId: groupId,
    );
    logger.detail('Updated: ${extensionEntitlements.path}');

    final runnerEntitlements = File(
      p.join(iosDir.path, 'Runner', 'Runner.entitlements'),
    );

    await ensureAppGroupEntitlement(
      entitlementsFile: runnerEntitlements,
      appGroupId: groupId,
    );
    logger.detail('Updated: ${runnerEntitlements.path}');

    if (xcodeproj.existsSync()) {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: xcodeproj,
        widgetClassName: widgetClassName,
      );

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: xcodeproj);
      await ensureMinimumDeploymentTargetInXcodeProject(pbxprojFile: xcodeproj);
      logger.detail('Updated: ${xcodeproj.path}');
    }
  }

  String _swiftDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return 'nil';
    if (defaultValue is String) {
      final escaped = defaultValue
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\r')
          .replaceAll('\t', r'\t');
      return '"$escaped"';
    }
    return '$defaultValue';
  }

  _SwiftJsonNode _buildJsonTree(List<JsonDataField> fields) {
    final root = _SwiftJsonNode();
    for (final field in fields) {
      var node = root;
      for (final segment in field.path) {
        node = node.children.putIfAbsent(segment, _SwiftJsonNode.new);
      }
      node.leafType = field.type;
    }
    return root;
  }

  void _writeSwiftJsonNodeStruct({
    required StringBuffer buffer,
    required String structName,
    required _SwiftJsonNode node,
    required bool isRoot,
  }) {
    buffer.writeln('struct $structName {');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final leaf = child.leafType!;
        final st = leaf.swiftType;
        if (leaf.defaultValue == null) {
          buffer.writeln('  let $key: $st?');
        } else {
          buffer.writeln(
            '  let $key: $st = ${_swiftDefaultLiteral(leaf)}',
          );
        }
      } else {
        final childStruct = '$structName${toPascalCase(key)}';
        buffer.writeln('  let $key: $childStruct?');
      }
    }
    buffer.writeln();
    if (isRoot) {
      buffer
          .writeln('  static func fromPath(_ path: String?) -> $structName? {');
      buffer.writeln('    guard let path else { return nil }');
      buffer.writeln(
        '    guard FileManager.default.fileExists(atPath: path) else { return nil }',
      );
      buffer.writeln('    do {');
      buffer.writeln(
        '      let data = try Data(contentsOf: URL(fileURLWithPath: path))',
      );
      buffer.writeln(
        '      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }',
      );
      buffer.writeln('      return fromJson(json)');
      buffer.writeln('    } catch {');
      buffer.writeln('      return nil');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
    }
    buffer.writeln(
      '  static func fromJson(_ json: [String: Any]?) -> $structName? {',
    );
    if (isRoot) {
      buffer.writeln('    guard let values = json else { return nil }');
    } else {
      buffer.writeln('    let values = json ?? [:]');
    }
    buffer.writeln('    return $structName(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final fallback = _swiftDefaultLiteral(child.leafType!);
        buffer.writeln(
          '      $key: (values["$key"] as? ${child.leafType!.swiftType}) ?? $fallback,',
        );
      } else {
        final childStruct = '$structName${toPascalCase(key)}';
        buffer.writeln(
          '      $key: $childStruct.fromJson(values["$key"] as? [String: Any]),',
        );
      }
    }
    buffer.writeln('    )');
    buffer.writeln('  }');
    buffer.writeln('}');

    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.children.isNotEmpty) {
        buffer.writeln();
        final childStruct = '$structName${toPascalCase(key)}';
        _writeSwiftJsonNodeStruct(
          buffer: buffer,
          structName: childStruct,
          node: child,
          isRoot: false,
        );
      }
    }
  }
}

class _SwiftJsonNode {
  final Map<String, _SwiftJsonNode> children = {};
  HWDataType<dynamic>? leafType;
}
