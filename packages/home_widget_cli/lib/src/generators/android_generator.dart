import 'dart:io';

import 'package:home_widget_generator/home_widget_generator_cli.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/widget_spec.dart';
import '../models/extensions.dart';
import '../util/android_package.dart';
import '../util/android_templates.dart';
import '../util/android_wiring.dart';
import '../util/localization_templates.dart';
import '../util/logger.dart';
import '../util/fs.dart';
import '../util/naming.dart';
import '../util/xml_utils.dart';
import 'kotlin_widget_emitter.dart';

/// Generates Android Glance widget files from a [WidgetSpec].
class AndroidGenerator {
  /// The widget specification to generate code for.
  final WidgetSpec spec;

  /// The root directory of the Flutter project.
  final Directory projectRoot;

  /// Creates a new [AndroidGenerator].
  AndroidGenerator({
    required this.spec,
    required this.projectRoot,
  });

  /// Generates the Android Glance widget files and wires them into Gradle
  /// and AndroidManifest.
  Future<void> generate() async {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final timedPrimitiveFields = spec.timedPrimitiveDataFields;
    final timedJsonGroups = spec.timedJsonDataGroups;
    final hasTimedFields = spec.timedDataFields.isNotEmpty;
    final hasDataFields =
        primitiveFields.isNotEmpty || jsonGroups.isNotEmpty || hasTimedFields;

    // The Kotlin `locales` parameter and every argument passed to it have to be
    // gated on this one flag; two separately-spelled "equivalent" conditions
    // emit Kotlin that does not compile.
    final needsLocaleArg = spec.resolvesLocalizedOnRead;
    final needsResolver = spec.needsLocaleHelpers;

    // Gallery strings do not count — the launcher resolves those on its own.
    final rendersLocalizedContent = spec.rendersLocalizedContent;

    final androidAppDir = Directory(p.join(projectRoot.path, 'android', 'app'));
    if (!androidAppDir.existsSync()) {
      logger.warn(
        'Warning: android/app/ not found. Skipping Android generation for ${spec.data.name}.',
      );
      return;
    }

    final detectedPackage = tryDetectAndroidPackage(projectRoot);
    final packageName =
        spec.data.android?.packageName ?? detectedPackage ?? 'com.example';
    final packagePath = packageName.split('.').join(p.separator);

    final widgetClassName = '${spec.className}HomeWidget';
    final providerInfoName = toSnakeCase(widgetClassName);

    final kotlinDir = Directory(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        packagePath,
      ),
    );

    final resXmlDir = Directory(
      p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res', 'xml'),
    );

    await ensureDir(kotlinDir);
    await ensureDir(resXmlDir);

    final widgetFile = File(p.join(kotlinDir.path, '$widgetClassName.kt'));

    String? dataClassContent;
    String? contentBody;

    if (hasDataFields) {
      final className = '${spec.className}Data';
      final buffer = StringBuffer();
      buffer.writeln('data class $className(');
      for (final field in primitiveFields) {
        final type = field.kotlinType;
        buffer.writeln('    val ${field.key}: $type? = null,');
      }
      for (final group in jsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln('    val ${group.key}: $jsonClass? = null,');
      }
      for (final field in timedPrimitiveFields) {
        buffer.writeln('    val ${field.key}: ${field.kotlinType}? = null,');
      }
      for (final group in timedJsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln('    val ${group.key}: $jsonClass? = null,');
      }
      buffer.writeln(') {');
      buffer.writeln('    companion object {');
      buffer.writeln(
        '        private const val PREFERENCES_PREFIX = "home_widget.${spec.className}"',
      );
      buffer.writeln();
      final localeParam = needsLocaleArg ? ', locales: List<String>' : '';
      if (hasTimedFields) {
        buffer.writeln(
          '        fun fromPreferences(prefs: android.content.SharedPreferences$localeParam, now: Long = System.currentTimeMillis()): $className {',
        );
        buffer.writeln(
          '            val timedValues = resolveTimedValues(prefs, now)',
        );
      } else {
        buffer.writeln(
          '        fun fromPreferences(prefs: android.content.SharedPreferences$localeParam): $className {',
        );
      }
      buffer.writeln('            return $className(');

      for (final field in primitiveFields) {
        final readLogic = field.androidReadValue(
          store: 'prefs',
          key: '\${PREFERENCES_PREFIX}.${field.key}',
        );
        buffer.writeln('                ${field.key} = $readLogic,');
      }
      for (final group in jsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln(
          '                ${group.key} = $jsonClass.fromPath(prefs.getString("\${PREFERENCES_PREFIX}.${group.key}", null)),',
        );
      }

      for (final field in timedPrimitiveFields) {
        // Checked before the plain leaf read, of which HWString — and so
        // HWLocalizedString — is one: a timed translation is stored as a locale
        // map, not as the text of a single locale.
        final valueExpr = field is HWLocalizedString
            ? field.androidTimedReadValue(valuesExpr: 'timedValues')
            : _androidLeafReadExpression(
                objExpr: 'timedValues',
                key: field.key,
                type: field,
              );
        buffer.writeln('                ${field.key} = $valueExpr,');
      }
      for (final group in timedJsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln(
          '                ${group.key} = $jsonClass.fromJson(timedValues.optJSONObject("${group.key}")),',
        );
      }

      buffer.writeln('            )');
      buffer.writeln('        }');
      if (hasTimedFields) {
        buffer.writeln();
        _writeKotlinTimedDataResolver(buffer);
      }
      buffer.writeln('    }');
      buffer.writeln('}');
      // Keys are unique within each list, and the validator forbids sharing a
      // root key between a timed and an untimed field, so class names never
      // collide across the two.
      for (final group in [...jsonGroups, ...timedJsonGroups]) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln();
        final tree = _buildJsonTree(group.children);
        _writeAndroidJsonNodeClass(
          buffer: buffer,
          className: jsonClass,
          node: tree,
          isRoot: true,
        );
      }
      dataClassContent = buffer.toString();
    }

    // Constants resolve through `R.string`; only strings the widget resolves
    // itself need the helpers, and only fields carrying stored translations
    // need a reader — from their own preferences key, from the timed entry, or
    // both, which is also exactly when the shared merge helpers are used.
    final localizationHelpers = <String>[
      if (needsResolver) kotlinLocalizeHelpers,
      if (needsLocaleArg) kotlinLocalizedMergeHelpers,
      if (spec.needsLocalizedRead) kotlinLocalizedReadHelper,
      if (spec.needsTimedLocalizedRead) kotlinTimedLocalizedReadHelper,
    ];
    if (localizationHelpers.isNotEmpty) {
      dataClassContent = [
        if (dataClassContent != null) dataClassContent,
        ...localizationHelpers,
      ].join('\n\n');
    }
    final bodyBuffer = StringBuffer();
    if (needsResolver) {
      bodyBuffer.writeln('    val hwLocales = hwCurrentLocales(context)');
    }
    if (hasDataFields) {
      final className = '${spec.className}Data';
      final localeArg = needsLocaleArg ? ', hwLocales' : '';
      bodyBuffer.writeln('    val prefs = currentState.preferences');
      bodyBuffer.writeln(
        '    val widgetData = $className.fromPreferences(prefs$localeArg)',
      );
    }

    final useTheme = spec.data.android?.useGlanceTheme ?? true;
    final bgColor = spec.data.android?.backgroundColor;
    final applyPadding = spec.data.android?.applyContentPadding ?? true;
    final fillContent = spec.data.android?.fillWidgetContent ?? true;

    var widgetTreeBody = emitKotlinWidgetBody(
      spec.effectiveWidgetTree,
      dataExpr: hasDataFields ? 'widgetData' : 'null',
      indent: useTheme ? 3 : 2, // inside WidgetContent, +1 if in GlanceTheme
    );

    final rootModifiers = <String>[];
    if (bgColor != null) {
      rootModifiers.add(
        'background(${bgColor.toKotlin(0, dataExpr: hasDataFields ? "widgetData" : "null")})',
      );
    }
    if (applyPadding) {
      rootModifiers.add('padding(16.dp)');
    }
    if (fillContent) {
      rootModifiers.add('fillMaxSize()');
      widgetTreeBody = wrapGlanceRootContent(
        widgetTreeBody,
        modifier: rootModifiers.join('.'),
      );
    } else {
      for (final modifier in rootModifiers) {
        widgetTreeBody = injectGlanceModifier(widgetTreeBody, modifier);
      }
    }

    if (useTheme) {
      bodyBuffer.writeln('    GlanceTheme {');
      bodyBuffer.writeln(widgetTreeBody);
      bodyBuffer.writeln('    }');
    } else {
      bodyBuffer.writeln(widgetTreeBody);
    }
    contentBody = bodyBuffer.toString();

    final layoutImports = (spec.effectiveWidgetTree.kotlinImports).toSet();
    if (useTheme) {
      layoutImports.add('import androidx.glance.GlanceTheme');
    }
    if (bgColor != null) {
      layoutImports.addAll(bgColor.kotlinImports);
      layoutImports.add('import androidx.glance.layout.Box');
    }
    if (applyPadding) {
      layoutImports.add('import androidx.compose.ui.unit.dp');
      layoutImports.add('import androidx.glance.layout.padding');
      layoutImports.add('import androidx.glance.layout.Box');
    }

    if (fillContent) {
      layoutImports.add('import androidx.glance.layout.fillMaxSize');
      layoutImports.add('import androidx.glance.layout.Alignment');
      layoutImports.add('import androidx.glance.layout.Box');
    }
    if (jsonGroups.isNotEmpty) {
      layoutImports.add('import java.io.File');
      layoutImports.add('import org.json.JSONObject');
    }
    // `R` lives in the Gradle namespace, not necessarily the package this file
    // is written into (an annotation may override `packageName`). Unqualified
    // `R` only resolves when the two coincide.
    if (spec.constantLocalizedStrings.isNotEmpty) {
      final rPackage =
          tryDetectAndroidNamespace(projectRoot) ?? detectedPackage;
      if (rPackage == null) {
        logger.warn(
          'Warning: could not detect the Android namespace. '
          '${widgetFile.path} references R.string, so the build will fail with '
          'an unresolved reference. Set android.packageName to the module '
          'namespace, or add the import manually.',
        );
      } else if (rPackage != packageName) {
        layoutImports.add('import $rPackage.R');
      }
    }

    await widgetFile.writeAsString(
      androidGlanceWidgetTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
        contentBody: contentBody,
        extraContent: dataClassContent,
        additionalImports: layoutImports.isNotEmpty ? layoutImports : null,
      ),
    );
    logger.detail('Generated: ${widgetFile.path}');

    final receiverFile = File(
      p.join(kotlinDir.path, '${widgetClassName}Receiver.kt'),
    );
    await receiverFile.writeAsString(
      androidGlanceReceiverTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
      ),
    );
    logger.detail('Generated: ${receiverFile.path}');

    final android = spec.data.android;
    final localization = spec.data.localization;

    final labelResourceName = spec.labelResourceName;
    final descriptionResourceName = spec.descriptionResourceName;

    final resources = <String, Map<String, String>>{};
    _collectLocalizedString(
      resources,
      name: labelResourceName,
      baseValue: spec.galleryName,
      translations: spec.galleryTranslations(localization?.name),
    );

    String? descriptionResource;
    final galleryDescription = spec.galleryDescription;
    if (galleryDescription != null) {
      _collectLocalizedString(
        resources,
        name: descriptionResourceName,
        baseValue: galleryDescription,
        translations: spec.galleryTranslations(localization?.description),
      );
      descriptionResource = '@string/$descriptionResourceName';
    }

    // Constant translations ship as resources so the platform resolves them
    // with the user's full language list and any per-app language override.
    for (final constant in spec.constantLocalizedStrings) {
      _collectLocalizedString(
        resources,
        name: constant.resourceName,
        baseValue: constant.baseValue,
        translations: {
          for (final entry in constant.defaultTranslations.entries)
            if (entry.key != constant.baseLocaleTag) entry.key: entry.value,
        },
      );
    }

    await _writeOwnedStringResources(projectRoot, resources);

    final providerInfoFile = File(
      p.join(resXmlDir.path, '$providerInfoName.xml'),
    );
    await providerInfoFile.writeAsString(
      androidAppWidgetProviderInfoTemplate(
        initialLayoutName: 'glance_default_loading_layout',
        minWidth: android?.minWidth ?? 80,
        minHeight: android?.minHeight ?? 80,
        minResizeWidth: android?.minResizeWidth,
        minResizeHeight: android?.minResizeHeight,
        maxResizeWidth: android?.maxResizeWidth,
        maxResizeHeight: android?.maxResizeHeight,
        targetCellWidth: android?.targetCellWidth,
        targetCellHeight: android?.targetCellHeight,
        resizeMode: android?.resizeMode?.toXmlValue() ?? 'horizontal|vertical',
        widgetCategory: android?.widgetCategory?.toXmlValue() ?? 'home_screen',
        updatePeriodMillis: android?.updatePeriodMillis ?? 0,
        descriptionResource: descriptionResource,
      ),
    );
    logger.detail('Generated: ${providerInfoFile.path}');

    await ensureAndroidGlanceGradleSetup(projectRoot);
    await ensureAndroidManifestReceiver(
      projectRoot,
      widgetClassName: widgetClassName,
      appPackageName: packageName,
      providerInfoName: providerInfoName,
      handleLocaleChange: rendersLocalizedContent,
      label: '@string/$labelResourceName',
    );
    if (spec.timedDataFields.isNotEmpty) {
      // Time-based content drives itself through HomeWidget.scheduleWidgetUpdates
      // on Android, which needs the plugin's scheduling receiver declared by the
      // consuming app. Specs without timed fields must not touch the manifest.
      await ensureAndroidManifestScheduledUpdates(projectRoot);
    }
  }

  Directory _resDir(Directory projectRoot) => Directory(
        p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res'),
      );

  /// The resource file every `<string>` this widget owns is written to.
  ///
  /// One file per widget per locale, owned outright by the generator: it is
  /// rewritten whole on every run, so stale entries disappear on their own. The
  /// app's own `strings.xml` is never read or written.
  String get _stringsFileName => '${spec.resourcePrefix}.xml';

  File _ownedStringsFile(Directory projectRoot, String qualifier) => File(
        p.join(
          _resDir(projectRoot).path,
          qualifier.isEmpty ? 'values' : 'values-$qualifier',
          _stringsFileName,
        ),
      );

  /// Records [name] under the base locale plus one entry per translation.
  ///
  /// [resources] maps an Android locale qualifier (`''` for the base `values`
  /// directory) to that locale's resource name/value pairs.
  void _collectLocalizedString(
    Map<String, Map<String, String>> resources, {
    required String name,
    required String baseValue,
    Map<String, String>? translations,
  }) {
    (resources[''] ??= {})[name] = baseValue;

    for (final entry
        in translations?.entries ?? const <MapEntry<String, String>>[]) {
      final qualifier = androidLocaleQualifier(entry.key);
      if (qualifier.isEmpty) continue;
      (resources[qualifier] ??= {})[name] = entry.value;
    }
  }

  /// The document written to one locale's owned resource file.
  XmlDocument _stringResourcesDocument(Map<String, String> resources) =>
      XmlDocument([
        XmlDeclaration([
          XmlAttribute(XmlName('version'), '1.0'),
          XmlAttribute(XmlName('encoding'), 'utf-8'),
        ]),
        XmlElement(
          XmlName('resources'),
          const [],
          [
            for (final entry in resources.entries)
              XmlElement(
                XmlName('string'),
                [
                  XmlAttribute(XmlName('name'), entry.key),
                  if (androidStringNeedsFormattedFalse(entry.value))
                    XmlAttribute(XmlName('formatted'), 'false'),
                ],
                [XmlText(androidStringResourceText(entry.value))],
              ),
          ],
        ),
      ]);

  /// Writes one owned file per locale in [resources], then drops the files this
  /// widget left behind in locales it no longer ships.
  Future<void> _writeOwnedStringResources(
    Directory projectRoot,
    Map<String, Map<String, String>> resources,
  ) async {
    for (final entry in resources.entries) {
      final file = _ownedStringsFile(projectRoot, entry.key);
      await ensureDir(file.parent);
      if (writeXmlFile(file, _stringResourcesDocument(entry.value))) {
        logger.detail('Generated: ${file.path}');
      }
    }

    await _pruneStaleLocaleFiles(projectRoot, live: resources.keys.toSet());
  }

  /// Matches the locale-qualified directories this generator creates, so
  /// pruning never touches `values-night`, `values-v31` and friends.
  static final RegExp _localeValuesDirPattern = RegExp(
    r'^values-(b\+[A-Za-z0-9+]+|[a-z]{2,3}(-r[A-Z]{2})?)$',
  );

  /// Deletes this widget's owned file from every locale directory not in
  /// [live], and the directory too once nothing is left in it.
  ///
  /// Only files named [_stringsFileName] are ever deleted; other widgets' files
  /// and the app's own resources share these directories.
  Future<void> _pruneStaleLocaleFiles(
    Directory projectRoot, {
    required Set<String> live,
  }) async {
    final resDir = _resDir(projectRoot);
    if (!resDir.existsSync()) return;

    for (final entity in resDir.listSync().whereType<Directory>()) {
      final dirName = p.basename(entity.path);
      if (!_localeValuesDirPattern.hasMatch(dirName)) continue;
      if (live.contains(dirName.substring('values-'.length))) continue;

      final file = File(p.join(entity.path, _stringsFileName));
      if (!file.existsSync()) continue;

      await file.delete();
      logger.detail('Removed stale: ${file.path}');

      if (entity.listSync().isEmpty) await entity.delete();
    }
  }

  /// Emits the companion-object helper resolving the timed data entry that is
  /// active at `now` (greatest timestamp <= now), or an empty object.
  ///
  /// Reads the same timed-data file — decimal epoch-millis string keys, one
  /// flat JSON object per timestamp — that `generate()` in
  /// dart_helper_generator.dart writes and `loadTimedEntries` in
  /// ios_generator.dart parses on iOS; the three must stay in step. A root
  /// localized field's timed value comes back as a locale-tag-to-text
  /// object rather than a plain value, matching how it was written.
  void _writeKotlinTimedDataResolver(StringBuffer buffer) {
    buffer.writeln(
      '        private fun resolveTimedValues(prefs: android.content.SharedPreferences, now: Long): org.json.JSONObject {',
    );
    buffer.writeln(
      '            val path = prefs.getString("\${PREFERENCES_PREFIX}.timedData", null) ?: return org.json.JSONObject()',
    );
    buffer.writeln('            return try {');
    buffer.writeln('                val file = java.io.File(path)');
    buffer.writeln(
      '                if (!file.exists()) return org.json.JSONObject()',
    );
    buffer.writeln(
      '                val json = org.json.JSONObject(file.readText())',
    );
    buffer.writeln('                var activeKey: String? = null');
    buffer.writeln('                var activeTimestamp = 0L');
    buffer.writeln('                val keys = json.keys()');
    buffer.writeln('                while (keys.hasNext()) {');
    buffer.writeln('                    val key = keys.next()');
    buffer.writeln(
      '                    val timestamp = key.toLongOrNull() ?: continue',
    );
    buffer.writeln(
      '                    if (timestamp <= now && (activeKey == null || timestamp > activeTimestamp)) {',
    );
    buffer.writeln('                        activeKey = key');
    buffer.writeln('                        activeTimestamp = timestamp');
    buffer.writeln('                    }');
    buffer.writeln('                }');
    buffer.writeln(
      '                val resolvedKey = activeKey ?: return org.json.JSONObject()',
    );
    buffer.writeln(
      '                json.optJSONObject(resolvedKey) ?: org.json.JSONObject()',
    );
    buffer.writeln('            } catch (_: Exception) {');
    buffer.writeln('                org.json.JSONObject()');
    buffer.writeln('            }');
    buffer.writeln('        }');
  }

  String _kotlinDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return 'null';
    if (defaultValue is String) {
      return '"${escapeKotlinStringLiteral(defaultValue)}"';
    }
    return '$defaultValue';
  }

  _JsonPathNode _buildJsonTree(List<JsonDataField> fields) {
    final root = _JsonPathNode();
    for (final field in fields) {
      var node = root;
      for (final segment in field.path) {
        node = node.children.putIfAbsent(segment, _JsonPathNode.new);
      }
      node.leafType = field.type;
    }
    return root;
  }

  void _writeAndroidJsonNodeClass({
    required StringBuffer buffer,
    required String className,
    required _JsonPathNode node,
    required bool isRoot,
  }) {
    buffer.writeln('data class $className(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final leaf = child.leafType!;
        final kt = leaf.kotlinType;
        if (leaf.defaultValue == null) {
          buffer.writeln('    val $key: $kt? = null,');
        } else {
          buffer.writeln(
            '    val $key: $kt = ${_kotlinDefaultLiteral(leaf)},',
          );
        }
      } else {
        final childClass = '$className${toPascalCase(key)}';
        buffer.writeln('    val $key: $childClass? = null,');
      }
    }
    buffer.writeln(') {');
    buffer.writeln('    companion object {');
    if (isRoot) {
      buffer.writeln('        fun fromPath(path: String?): $className? {');
      buffer.writeln('            if (path == null) return null');
      buffer.writeln('            return try {');
      buffer.writeln('                val file = java.io.File(path)');
      buffer.writeln('                if (!file.exists()) return null');
      buffer.writeln(
        '                fromJson(org.json.JSONObject(file.readText()))',
      );
      buffer.writeln('            } catch (_: Exception) {');
      buffer.writeln('                null');
      buffer.writeln('            }');
      buffer.writeln('        }');
      buffer.writeln();
    }
    buffer.writeln(
      '        fun fromJson(obj: org.json.JSONObject?): $className? {',
    );
    if (isRoot) {
      buffer.writeln('            if (obj == null) return null');
      buffer.writeln('            val json = obj');
    } else {
      buffer.writeln('            val json = obj ?: org.json.JSONObject()');
    }
    buffer.writeln('            return $className(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final valueExpr = _androidLeafReadExpression(
          objExpr: 'json',
          key: key,
          type: child.leafType!,
        );
        buffer.writeln('                $key = $valueExpr,');
      } else {
        final childClass = '$className${toPascalCase(key)}';
        buffer.writeln(
          '                $key = $childClass.fromJson(json.optJSONObject("$key")),',
        );
      }
    }
    buffer.writeln('            )');
    buffer.writeln('        }');
    buffer.writeln('    }');
    buffer.writeln('}');

    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.children.isNotEmpty) {
        buffer.writeln();
        final childClass = '$className${toPascalCase(key)}';
        _writeAndroidJsonNodeClass(
          buffer: buffer,
          className: childClass,
          node: child,
          isRoot: false,
        );
      }
    }
  }

  String _androidLeafReadExpression({
    required String objExpr,
    required String key,
    required HWDataType<dynamic> type,
  }) {
    final fallback = _kotlinDefaultLiteral(type);
    if (type is HWString) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optString("$key") else $fallback';
    }
    if (type is HWInt) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optInt("$key") else $fallback';
    }
    if (type is HWDouble) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optDouble("$key") else $fallback';
    }
    if (type is HWBool) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optBoolean("$key") else $fallback';
    }
    return fallback;
  }
}

class _JsonPathNode {
  final Map<String, _JsonPathNode> children = {};
  HWDataType<dynamic>? leafType;
}
