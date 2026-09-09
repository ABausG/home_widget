import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';
import 'package:path/path.dart' as p;

import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../models/extensions.dart';
import '../util/logger.dart';
import '../util/entitlements.dart';
import '../util/fs.dart';
import '../util/ios_templates.dart';
import '../util/localization_templates.dart';
import '../util/naming.dart';
import '../util/string_catalog.dart';
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
    final timedPrimitiveFields = spec.timedPrimitiveDataFields;
    final timedJsonGroups = spec.timedJsonDataGroups;
    final hasTimedFields = spec.timedDataFields.isNotEmpty;
    final hasDataFields =
        primitiveFields.isNotEmpty || jsonGroups.isNotEmpty || hasTimedFields;
    final needsEntryTimedEntries = spec.needsLocaleHelpers && hasTimedFields;

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

    // Before anything is written: a flavor the Xcode project does not have
    // compiles the widget out of every build, so there is nothing worth
    // generating until the configurations exist.
    if (xcodeproj.existsSync()) {
      _requireXcodeFlavors(await xcodeproj.readAsString(), iosDir);
    }

    final widgetClassName = '${spec.className}HomeWidget';
    final groupId = spec.iosGroupIdFor(null);
    final flavorAppGroupIds = {
      for (final flavor in spec.declaredFlavors)
        flavor: spec.iosGroupIdFor(flavor),
    };
    final prefsExpr =
        'UserDefaults(suiteName: ${iosFlavorEnumName(widgetClassName)}.appGroupId)';

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
      for (final field in timedPrimitiveFields) {
        buffer.writeln('  let ${field.key}: ${field.swiftType}?');
      }
      for (final group in timedJsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln('  let ${group.key}: $jsonClass?');
      }
      buffer.writeln();
      buffer.writeln(
        '  static let paramPrefix = "home_widget.${spec.className}"',
      );
      buffer.writeln();
      if (hasTimedFields) {
        buffer.writeln('  static func fromUserDefaults(');
        buffer.writeln('    _ defaults: UserDefaults?,');
        buffer.writeln('    at date: Date = Date(),');
        buffer.writeln(
          '    timedEntries: [(date: Date, values: [String: Any])]? = nil',
        );
        buffer.writeln('  ) -> $className {');
        buffer.writeln(
          '    let timedValues = activeTimedValues(timedEntries ?? loadTimedEntries(defaults), at: date)',
        );
      } else {
        buffer.writeln(
          '  static func fromUserDefaults(_ defaults: UserDefaults?) -> $className {',
        );
      }
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
      for (final field in timedPrimitiveFields) {
        // Checked before the plain cast, which would read a timed translation
        // as the text of a single locale rather than as the locale map it is.
        if (field is HWLocalizedString) {
          buffer.writeln(
            '      ${field.key}: '
            '${field.iosTimedReadValue(valuesExpr: 'timedValues')},',
          );
          continue;
        }
        // Also checked before the plain cast: a date travels as an ISO string,
        // so casting the entry value to `Date` would always miss.
        if (field is HWDateTime) {
          buffer.writeln(
            '      ${field.key}: '
            '${field.iosTimedReadValue(valuesExpr: 'timedValues')},',
          );
          continue;
        }
        final fallback = field.codegenSwiftDefaultLiteral();
        final read = 'timedValues["${field.key}"] as? ${field.swiftType}';
        buffer.writeln(
          '      ${field.key}: ${fallback == null ? read : '($read) ?? $fallback'},',
        );
      }
      for (final group in timedJsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln(
          '      ${group.key}: $jsonClass.fromJson(timedValues["${group.key}"] as? [String: Any]),',
        );
      }
      buffer.writeln('    )');
      buffer.writeln('  }');
      if (hasTimedFields) {
        buffer.writeln();
        _writeSwiftTimedDataHelpers(buffer);
      }
      buffer.writeln('}');
      // Keys are unique within each list, and the validator forbids sharing a
      // root key between a timed and an untimed field, so struct names never
      // collide across the two.
      for (final group in [...jsonGroups, ...timedJsonGroups]) {
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

      entryDefinition = needsEntryTimedEntries
          ? '''
struct ${widgetClassName}Entry: TimelineEntry {
  let date: Date
  let data: $className
  let timedEntries: [(date: Date, values: [String: Any])]
}
'''
          : '''
struct ${widgetClassName}Entry: TimelineEntry {
  let date: Date
  let data: $className
}
''';

      final loadDataLogic = '''
    let prefs = $prefsExpr
    let data = $className.fromUserDefaults(prefs)
''';
      getSnapshotBody = needsEntryTimedEntries
          ? '''
    let prefs = $prefsExpr
    let timedEntries = $className.loadTimedEntries(prefs)
    let data = $className.fromUserDefaults(prefs, timedEntries: timedEntries)

    completion(${widgetClassName}Entry(date: Date(), data: data, timedEntries: timedEntries))
'''
          : '''
$loadDataLogic
    completion(${widgetClassName}Entry(date: Date(), data: data))
''';
      getTimelineBody = hasTimedFields
          ? '''
    let prefs = $prefsExpr
    let timedEntries = $className.loadTimedEntries(prefs)
    let now = Date()
    var entries: [${widgetClassName}Entry] = [
      ${widgetClassName}Entry(
        date: now,
        data: $className.fromUserDefaults(prefs, at: now, timedEntries: timedEntries)${needsEntryTimedEntries ? ',\n        timedEntries: timedEntries' : ''}
      )
    ]
    for timedEntry in timedEntries where timedEntry.date > now {
      entries.append(
        ${widgetClassName}Entry(
          date: timedEntry.date,
          data: $className.fromUserDefaults(prefs, at: timedEntry.date, timedEntries: timedEntries)${needsEntryTimedEntries ? ',\n          timedEntries: timedEntries' : ''}
        )
      )
    }
    completion(Timeline(entries: entries, policy: .atEnd))
'''
          : '''
$loadDataLogic
    completion(Timeline(entries: [${widgetClassName}Entry(date: Date(), data: data)], policy: .atEnd))
''';
    }

    // File-scope helpers, each emitted only for the widgets that reach it.
    //
    // Localization: constants and gallery strings resolve through the string
    // catalog; only strings the widget resolves itself need the helpers, and
    // only fields carrying stored translations need a reader — from their own
    // preferences key, from the timed entry, or both, which is also exactly
    // when the shared merge helpers are used.
    //
    // Images: every image is decoded through the downsampling helper, whatever
    // its source; bundled ones additionally need their path resolved out of
    // the containing app.
    //
    // Formatting: the spec resolves the number, date and time-zone helpers the
    // tree and the declared fields reach to their transitive closure, already
    // ordered so each one is declared after what it calls.
    final fileHelpers = <String>[
      if (spec.needsLocaleHelpers) swiftLocalizeHelpers,
      if (spec.resolvesLocalizedOnRead) swiftLocalizedMergeHelpers,
      if (spec.needsLocalizedRead) swiftLocalizedReadHelper,
      if (spec.needsTimedLocalizedRead) swiftTimedLocalizedReadHelper,
      if (spec.hasImages) swiftImageDecodeHelper,
      if (spec.assetImageFields.isNotEmpty) swiftFlutterAssetHelper,
      for (final helper in spec.nativeHelpers)
        helper.toSwift(0, dataExpr: '').trim(),
    ];
    if (fileHelpers.isNotEmpty) {
      extraContent = [
        if (extraContent != null) extraContent,
        ...fileHelpers,
      ].join('\n\n');
    }

    // Localized strings must be resolved at render time so a system language
    // change is picked up without waiting for a new timeline. Timeline entries
    // still carry a snapshot for WidgetKit, but the view re-reads.
    final reResolveAtRender = spec.needsLocaleHelpers;
    final dataExpr = !hasDataFields
        ? 'null'
        : reResolveAtRender
            ? 'data'
            : 'entry.data';

    // The re-read has to land on the same instant WidgetKit is rendering, or
    // every entry of the timeline would show the values that were active when
    // the timeline was built and no timed change would ever appear.
    final atEntryDate = hasTimedFields ? ', at: entry.date' : '';
    final entryTimedEntriesArg =
        needsEntryTimedEntries ? ', timedEntries: entry.timedEntries' : '';
    final viewPrefix = reResolveAtRender
        ? '    let prefs = $prefsExpr\n'
            '    let data = ${spec.className}Data'
            '.fromUserDefaults(prefs$atEntryDate$entryTimedEntriesArg)\n'
        : '';

    final treeCode = emitSwiftWidgetBody(
      spec.effectiveWidgetTree,
      dataExpr: dataExpr,
      indent: 2,
    );

    final customBgColor = spec.data.iOS?.backgroundColor;
    final applyPadding = spec.data.iOS?.applyContentPadding ?? true;
    final hasCustomBg = customBgColor != null;
    final containerBackgroundModifier = hasCustomBg
        ? '.applyContainerBackground(${customBgColor.toSwift(2, dataExpr: dataExpr)})'
        : '.applyContainerBackground()';
    entryViewBody = '$viewPrefix$treeCode\n    $containerBackgroundModifier';

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
        flavorAppGroupIds: flavorAppGroupIds,
        widgetUrl: spec.iosWidgetUrl == null
            ? null
            : escapeSwiftStringLiteral(spec.iosWidgetUrl!),
        placeholderBody: hasDataFields
            ? '${widgetClassName}Entry(date: Date(), data: ${spec.className}Data'
                '.fromUserDefaults(nil)'
                '${needsEntryTimedEntries ? ', timedEntries: []' : ''})'
            : null,
        extraContent: extraContent,
        // CGImageSource lives in ImageIO, which SwiftUI does not re-export.
        extraImports: [if (spec.hasImages) 'import ImageIO'],
        entryDefinition: entryDefinition,
        getSnapshotBody: getSnapshotBody,
        getTimelineBody: getTimelineBody,
        entryViewBody: entryViewBody,
        displayName: spec.galleryName,
        description: spec.galleryDescription,
        displayNameExpression: _galleryStringExpression(
          resourceName: spec.labelResourceName,
          translations: spec.data.localization?.name,
        ),
        descriptionExpression: spec.galleryDescription == null
            ? null
            : _galleryStringExpression(
                resourceName: spec.descriptionResourceName,
                translations: spec.data.localization?.description,
              ),
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
      iosWidgetBundleSwiftTemplate(
        widgetClassName: widgetClassName,
        flavors: spec.declaredFlavors,
      ),
    );
    logger.detail('Generated: ${widgetBundleSwift.path}');

    await infoPlist.writeAsString(iosInfoPlistTemplate());
    logger.detail('Generated: ${infoPlist.path}');

    final catalogEntries = _stringCatalogEntries();
    final catalogFile = File(
      p.join(extensionDir.path, 'Localizable.xcstrings'),
    );
    if (catalogEntries.isNotEmpty) {
      await catalogFile.writeAsString(
        stringCatalogJson(
          sourceLanguage: spec.defaultLocale,
          entries: catalogEntries,
        ),
      );
      logger.detail('Generated: ${catalogFile.path}');
    }

    await ensureAppGroupEntitlement(
      entitlementsFile: extensionEntitlements,
      appGroupId: groupId,
    );
    logger.detail('Updated: ${extensionEntitlements.path}');

    final flavorEntitlements = <String, String>{};
    for (final flavor in spec.declaredFlavors) {
      final name = '$widgetClassName.$flavor.entitlements';
      final file = File(p.join(iosDir.path, name));
      await ensureAppGroupEntitlement(
        entitlementsFile: file,
        appGroupId: flavorAppGroupIds[flavor]!,
      );
      logger.detail('Updated: ${file.path}');
      flavorEntitlements[flavor] = name;
    }

    if (xcodeproj.existsSync()) {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: xcodeproj,
        widgetClassName: widgetClassName,
        flavorEntitlements: flavorEntitlements,
      );

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: xcodeproj);
      await ensureMinimumDeploymentTargetInXcodeProject(pbxprojFile: xcodeproj);

      // Never wire a catalog we did not write: a stale reference to a missing
      // file fails the build.
      if (catalogEntries.isNotEmpty) {
        await ensureLocalizableCatalogInXcodeProject(
          pbxprojFile: xcodeproj,
          widgetClassName: widgetClassName,
          locales: spec.supportedLocales,
        );
      }
      logger.detail('Updated: ${xcodeproj.path}');
    }

    // Read back only now: the Runner configurations this looks at are the ones
    // the patchers above just settled.
    final pbxproj =
        xcodeproj.existsSync() ? await xcodeproj.readAsString() : null;
    if (pbxproj != null) _reportFlavorMismatches(pbxproj, iosDir);
    await _updateRunnerEntitlements(
      iosDir: iosDir,
      pbxproj: pbxproj,
      groupId: groupId,
      flavorAppGroupIds: flavorAppGroupIds,
    );
  }

  /// Fails when a declared flavor has no Xcode build configurations.
  ///
  /// The widget is guarded by the compilation conditions of the flavors it
  /// declares, and those only exist on configurations mirroring a Runner
  /// `Debug-<flavor>`: without them the guard is never satisfied and the widget
  /// silently disappears from every build.
  void _requireXcodeFlavors(String pbxproj, Directory iosDir) {
    if (!spec.hasFlavors) return;
    final detected = detectXcodeFlavors(pbxproj, projectDir: iosDir);
    final missing = spec.declaredFlavors
        .where((flavor) => !detected.contains(flavor))
        .toList(growable: false);
    if (missing.isEmpty) return;

    final wanted = missing
        .map(
          (flavor) => '"$flavor" needs Debug-$flavor, Release-$flavor and '
              'Profile-$flavor',
        )
        .join('; ');
    throw GeneratorError(
      '${spec.data.name} declares the flavor'
      '${missing.length == 1 ? '' : 's'} '
      '${missing.map((flavor) => '"$flavor"').join(', ')}, which '
      'Runner.xcodeproj does not have: $wanted. '
      '${detected.isEmpty ? 'It defines no flavored build configurations at all.' : 'It defines ${detected.map((flavor) => '"$flavor"').join(', ')}.'} '
      'Add the build configurations, then generate again.',
    );
  }

  /// Adds every App Group the widget uses to the Runner entitlements that
  /// carry it.
  ///
  /// A flavor signs with the files its own Runner configurations name, so its
  /// group has to land in every one of them rather than in the shared one — the
  /// Debug and Release configurations of a flavor routinely sign with different
  /// files, and a group written to only one of them is missing from the other's
  /// builds. Flavors whose configurations name none fall back to the file the
  /// scaffolder creates.
  ///
  /// A configuration naming a file through a build variable only Xcode can
  /// resolve is left to the user: writing to a guessed path would create a
  /// second entitlements file that nothing signs with.
  Future<void> _updateRunnerEntitlements({
    required Directory iosDir,
    required String? pbxproj,
    required String groupId,
    required Map<String, String> flavorAppGroupIds,
  }) async {
    const defaultPath = 'Runner/Runner.entitlements';
    final groupsByPath = <String, Set<String>>{};

    for (final entry in <String?, String>{
      null: groupId,
      ...flavorAppGroupIds,
    }.entries) {
      final flavor = entry.key;
      final settings = pbxproj == null
          ? const <String>[]
          : runnerEntitlementsSettingsForFlavor(
              pbxproj,
              flavor,
              projectDir: iosDir,
            );
      if (settings.isEmpty) {
        groupsByPath
            .putIfAbsent(defaultPath, () => <String>{})
            .add(entry.value);
        continue;
      }

      for (final setting in settings) {
        final path = resolveProjectRelativePath(setting);
        if (path == null) {
          logger.warn(
            'Warning: The Runner configuration '
            '${flavor == null ? '' : 'of flavor "$flavor" '}signs with '
            '"$setting", which only Xcode can resolve. Add the App Group '
            '${entry.value} to that entitlements file by hand.',
          );
          continue;
        }
        groupsByPath.putIfAbsent(path, () => <String>{}).add(entry.value);
      }
    }

    for (final entry in groupsByPath.entries) {
      final file = File(p.join(iosDir.path, entry.key));
      for (final appGroupId in entry.value) {
        await ensureAppGroupEntitlement(
          entitlementsFile: file,
          appGroupId: appGroupId,
        );
      }
      logger.detail('Updated: ${file.path}');
      if (entry.value.length > 1) {
        logger.info(
          '${entry.key} now lists several App Groups '
          '(${entry.value.join(', ')}) because the flavors sharing it use '
          'different ones. Point each flavor at its own Runner entitlements '
          'file via CODE_SIGN_ENTITLEMENTS to keep them apart.',
        );
      }
    }
  }

  /// Notes the Xcode flavors the widget leaves out.
  void _reportFlavorMismatches(String pbxproj, Directory iosDir) {
    if (!spec.hasFlavors) return;
    final detected = detectXcodeFlavors(pbxproj, projectDir: iosDir);

    for (final flavor in detected) {
      if (spec.declaredFlavors.contains(flavor)) continue;
      logger.detail(
        '${spec.data.name} is not generated for the Xcode flavor "$flavor".',
      );
    }
  }

  /// Swift expression for a gallery string, or null when nothing was
  /// translated and the plain `LocalizedStringKey` literal should stay.
  String? _galleryStringExpression({
    required String resourceName,
    required Map<String, String>? translations,
  }) {
    if (translations == null || translations.isEmpty) return null;
    return 'NSLocalizedString("$resourceName", comment: "")';
  }

  /// The entries the extension's string catalog has to carry.
  ///
  /// Maps resource name to locale tag → text, always including the default
  /// locale. Empty when the widget has nothing fixed to translate, in which
  /// case no catalog is written and none is wired into the Xcode project.
  Map<String, Map<String, String>> _stringCatalogEntries() {
    final defaultLocale = spec.defaultLocale;
    final entries = <String, Map<String, String>>{};

    for (final constant in spec.constantLocalizedStrings) {
      entries[constant.resourceName] = {
        defaultLocale: constant.baseValue,
        ...constant.defaultTranslations,
      };
    }

    final localization = spec.data.localization;
    final nameTranslations = localization?.name;
    if (nameTranslations != null && nameTranslations.isNotEmpty) {
      entries[spec.labelResourceName] = {
        ...nameTranslations,
        defaultLocale: spec.galleryName,
      };
    }

    final descriptionTranslations = localization?.description;
    final description = spec.galleryDescription;
    if (description != null &&
        descriptionTranslations != null &&
        descriptionTranslations.isNotEmpty) {
      entries[spec.descriptionResourceName] = {
        ...descriptionTranslations,
        defaultLocale: description,
      };
    }

    return entries;
  }

  /// Emits the timed-data file loader and the active-entry resolver used by
  /// `fromUserDefaults` when the spec has [WidgetSpec.timedDataFields].
  ///
  /// Both statics are implementation details of the generated file, so they are
  /// `fileprivate` rather than public. They cannot be `private`: Swift's
  /// `private` is lexically scoped to the enclosing declaration, and
  /// `loadTimedEntries` is called from the provider's `getTimeline`, a
  /// different type in the same file.
  ///
  /// `loadTimedEntries` parses the same timed-data file — decimal epoch-millis
  /// string keys, one flat JSON object per timestamp — that `generate()` in
  /// dart_helper_generator.dart writes and `resolveTimedValues` in
  /// android_generator.dart parses on Android; the three must stay in step. A
  /// root localized field's timed value is stored as a locale-tag-to-text
  /// object rather than a plain value, so callers read `values[key]` as a
  /// `[String: Any]`, not the leaf type.
  void _writeSwiftTimedDataHelpers(StringBuffer buffer) {
    buffer.writeln(
      '  fileprivate static func loadTimedEntries(_ defaults: UserDefaults?) -> [(date: Date, values: [String: Any])] {',
    );
    buffer.writeln(
      '    guard let path = defaults?.string(forKey: "\\(paramPrefix).timedData") else { return [] }',
    );
    buffer.writeln(
      '    guard FileManager.default.fileExists(atPath: path) else { return [] }',
    );
    buffer.writeln('    do {');
    buffer.writeln(
      '      let raw = try Data(contentsOf: URL(fileURLWithPath: path))',
    );
    buffer.writeln(
      '      guard let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return [] }',
    );
    buffer.writeln(
      '      var entries: [(date: Date, values: [String: Any])] = []',
    );
    buffer.writeln('      for (key, value) in json {');
    buffer.writeln(
      '        guard let millis = Double(key), let values = value as? [String: Any] else { continue }',
    );
    buffer.writeln(
      '        entries.append((date: Date(timeIntervalSince1970: millis / 1000), values: values))',
    );
    buffer.writeln('      }');
    buffer.writeln('      entries.sort { \$0.date < \$1.date }');
    buffer.writeln('      return entries');
    buffer.writeln('    } catch {');
    buffer.writeln('      return []');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  fileprivate static func activeTimedValues(_ entries: [(date: Date, values: [String: Any])], at date: Date) -> [String: Any] {',
    );
    buffer.writeln('    var values: [String: Any] = [:]');
    buffer.writeln('    for entry in entries {');
    buffer.writeln('      if entry.date > date { break }');
    buffer.writeln('      values = entry.values');
    buffer.writeln('    }');
    buffer.writeln('    return values');
    buffer.writeln('  }');
  }

  String _swiftDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return 'nil';
    if (defaultValue is String) {
      return '"${escapeSwiftStringLiteral(defaultValue)}"';
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
        // A `let` with an initializer drops out of the memberwise init, which
        // `fromJson` — the only place these structs are built — calls with
        // every property. The default is applied there instead.
        buffer.writeln(
          leaf.defaultValue == null ? '  let $key: $st?' : '  let $key: $st',
        );
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
        final leaf = child.leafType!;
        // A date leaf is stored as an ISO string, so it is parsed rather than
        // cast, and has no default to fall back on.
        if (leaf is HWDateTime) {
          buffer.writeln(
            '      $key: '
            '${leaf.iosJsonReadValue(objExpr: 'values', key: key)},',
          );
          continue;
        }
        final read = 'values["$key"] as? ${leaf.swiftType}';
        // The conditional cast already yields nil when the value is absent or
        // of another type; coalescing that to nil again is a Swift warning.
        final fallback =
            leaf.defaultValue == null ? null : _swiftDefaultLiteral(leaf);
        buffer.writeln(
          '      $key: ${fallback == null ? read : '($read) ?? $fallback'},',
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
