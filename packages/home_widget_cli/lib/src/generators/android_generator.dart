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
    final hasDataFields = primitiveFields.isNotEmpty || jsonGroups.isNotEmpty;

    // One predicate for the `locales` parameter and the argument passed to it:
    // gating the two on separately-spelled but "equivalent" conditions is how
    // uncompilable Kotlin gets reported as a successful generation.
    final needsLocaleArg = spec.needsLocaleHelpers;

    // Whether this widget renders localized text itself, and so goes stale on
    // a system language change unless the receiver re-renders it. Gallery
    // strings do not count — the launcher resolves those on its own.
    final rendersLocalizedContent = spec.constantLocalizedStrings.isNotEmpty ||
        spec.keyedLocalizedStrings.isNotEmpty;

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
      buffer.writeln(') {');
      buffer.writeln('    companion object {');
      buffer.writeln(
        '        private const val PREFERENCES_PREFIX = "home_widget.${spec.className}"',
      );
      buffer.writeln();
      final localeParam = needsLocaleArg ? ', locales: List<String>' : '';
      buffer.writeln(
        '        fun fromPreferences(prefs: android.content.SharedPreferences$localeParam): $className {',
      );
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

      buffer.writeln('            )');
      buffer.writeln('        }');
      buffer.writeln('    }');
      buffer.writeln('}');
      for (final group in jsonGroups) {
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

    // Constants resolve through `R.string`, so only keyed strings — whose
    // runtime overrides live in a preferences blob — still need the resolver.
    final localizationHelpers = <String>[
      if (needsLocaleArg) kotlinLocalizeHelpers,
      if (needsLocaleArg) kotlinLocalizedReadHelper,
    ];
    if (localizationHelpers.isNotEmpty) {
      dataClassContent = [
        if (dataClassContent != null) dataClassContent,
        ...localizationHelpers,
      ].join('\n\n');
    }
    final bodyBuffer = StringBuffer();
    if (needsLocaleArg) {
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
    // `R` is generated under the Gradle namespace, which is not necessarily the
    // package this file is written into: an annotation that overrides
    // `packageName` puts it somewhere else. Unqualified `R` only resolves when
    // the two coincide, so anywhere else the import has to be explicit.
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
        handleLocaleChange: rendersLocalizedContent,
      ),
    );
    logger.detail('Generated: ${receiverFile.path}');

    final android = spec.data.android;
    final localization = spec.data.localization;

    // Everything under `home_widget_` is ours and is rewritten on every run.
    final labelResourceName = spec.labelResourceName;
    final descriptionResourceName = spec.descriptionResourceName;

    await _writeLocalizedStringResource(
      projectRoot,
      name: labelResourceName,
      baseValue: spec.data.name,
      translations: localization?.name,
    );

    String? descriptionResource;
    if (spec.data.description != null && spec.data.description!.isNotEmpty) {
      await _writeLocalizedStringResource(
        projectRoot,
        name: descriptionResourceName,
        baseValue: spec.data.description!,
        translations: localization?.description,
      );
      descriptionResource = '@string/$descriptionResourceName';
    }

    // Constant translations ship as resources so the platform resolves them
    // with the user's full language list and any per-app language override.
    final constantResourceNames = <String>{};
    for (final constant in spec.constantLocalizedStrings) {
      constantResourceNames.add(constant.resourceName);
      await _writeLocalizedStringResource(
        projectRoot,
        name: constant.resourceName,
        baseValue: constant.baseValue,
        translations: {
          for (final entry in constant.defaultTranslations.entries)
            if (entry.key != constant.baseLocaleTag) entry.key: entry.value,
        },
      );
    }

    await _pruneStaleConstantResources(
      projectRoot,
      prefix: spec.resourcePrefix,
      live: constantResourceNames,
    );

    await _removeLegacyStringResource(
      projectRoot,
      name: '${providerInfoName}_description',
    );

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
  }

  File _stringsFile(Directory projectRoot, String? locale) {
    final qualifier = locale == null ? '' : androidLocaleQualifier(locale);
    final dirName = qualifier.isEmpty ? 'values' : 'values-$qualifier';
    return File(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'res',
        dirName,
        'strings.xml',
      ),
    );
  }

  XmlElement _stringElement(String name, String value) => XmlElement(
        XmlName('string'),
        [
          XmlAttribute(XmlName('name'), name),
          if (androidStringNeedsFormattedFalse(value))
            XmlAttribute(XmlName('formatted'), 'false'),
        ],
        [XmlText(androidStringResourceText(value))],
      );

  /// Writes a `<string>` we own into `values[-<qualifier>]/strings.xml`.
  ///
  /// Existing entries under the same name are **replaced**: everything under the
  /// `home_widget_` prefix is generated output, so the annotation stays the
  /// source of truth and edits to it always reach the app. Entries outside the
  /// prefix are never touched.
  Future<void> _writeStringResource(
    Directory projectRoot, {
    required String name,
    required String value,
    String? locale,
  }) async {
    final stringsFile = _stringsFile(projectRoot, locale);

    if (!stringsFile.existsSync()) {
      await stringsFile.create(recursive: true);
      final doc = XmlDocument([
        XmlProcessing('xml', 'version="1.0" encoding="utf-8"'),
        XmlElement(XmlName('resources'), const [], [
          _stringElement(name, value),
        ]),
      ]);
      writeXmlFile(stringsFile, doc);
      logger.detail('Generated: ${stringsFile.path}');
      return;
    }

    final doc = tryParseXmlFile(stringsFile);
    if (doc == null) {
      // coverage:ignore-start
      return;
      // coverage:ignore-end
    }

    final resources = doc.rootElement;
    final existing = resources.childElements
        .where(
          (e) => e.localName == 'string' && e.getAttribute('name') == name,
        )
        .toList();
    for (final element in existing) {
      element.remove();
    }

    resources.children.add(_stringElement(name, value));

    writeXmlFile(stringsFile, doc);
    logger.detail('Updated: ${stringsFile.path}');
  }

  /// Matches the locale-qualified directories this generator creates, so
  /// pruning never touches `values-night`, `values-v31` and friends.
  static final RegExp _localeValuesDirPattern = RegExp(
    r'^values-(b\+[A-Za-z0-9+]+|[a-z]{2,3}(-r[A-Z]{2})?)$',
  );

  /// Writes the base value plus one entry per translated locale, and drops the
  /// entry from locales that are no longer translated.
  ///
  /// Pruning is what makes "the annotation is the source of truth" true. Without
  /// it, deleting a translation would leave the previously generated
  /// `values-<locale>/strings.xml` entry in place, and the app would keep
  /// shipping it with nothing in the generated output to reveal that.
  Future<void> _writeLocalizedStringResource(
    Directory projectRoot, {
    required String name,
    required String baseValue,
    Map<String, String>? translations,
  }) async {
    await _writeStringResource(projectRoot, name: name, value: baseValue);

    final live = <String>{
      for (final locale in translations?.keys ?? const <String>[])
        'values-${androidLocaleQualifier(locale)}',
    };

    for (final entry
        in translations?.entries ?? const <MapEntry<String, String>>[]) {
      await _writeStringResource(
        projectRoot,
        name: name,
        value: entry.value,
        locale: entry.key,
      );
    }

    await _pruneStaleLocaleResources(projectRoot, name: name, live: live);
  }

  /// Removes [name] from every locale-qualified `strings.xml` not in [live].
  Future<void> _pruneStaleLocaleResources(
    Directory projectRoot, {
    required String name,
    required Set<String> live,
  }) async {
    final resDir = Directory(
      p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res'),
    );
    if (!resDir.existsSync()) return;

    for (final entity in resDir.listSync().whereType<Directory>()) {
      final dirName = p.basename(entity.path);
      if (!_localeValuesDirPattern.hasMatch(dirName)) continue;
      if (live.contains(dirName)) continue;

      final stringsFile = File(p.join(entity.path, 'strings.xml'));
      if (!stringsFile.existsSync()) continue;

      final doc = tryParseXmlFile(stringsFile);
      if (doc == null) continue;

      final stale = doc.rootElement.childElements
          .where(
            (e) => e.localName == 'string' && e.getAttribute('name') == name,
          )
          .toList();
      if (stale.isEmpty) continue;

      for (final element in stale) {
        element.remove();
      }
      writeXmlFile(stringsFile, doc);
      logger.detail('Removed stale "$name" from ${stringsFile.path}');
    }
  }

  /// Removes constant-translation entries this widget no longer generates.
  ///
  /// The resource name carries a hash of the translations, so editing one
  /// produces a new name rather than overwriting the old entry. Without this
  /// sweep every edit would leave its predecessor behind, and the app would go
  /// on shipping strings that no longer appear anywhere in the annotation.
  ///
  /// Only `<prefix>_t_*` is considered: gallery entries, other widgets and
  /// hand-written strings all fall outside it.
  Future<void> _pruneStaleConstantResources(
    Directory projectRoot, {
    required String prefix,
    required Set<String> live,
  }) async {
    final resDir = Directory(
      p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res'),
    );
    if (!resDir.existsSync()) return;

    final ownedPattern = RegExp('^${RegExp.escape(prefix)}_t_[0-9a-f]+\$');

    for (final entity in resDir.listSync().whereType<Directory>()) {
      final dirName = p.basename(entity.path);
      if (dirName != 'values' && !_localeValuesDirPattern.hasMatch(dirName)) {
        continue;
      }

      final stringsFile = File(p.join(entity.path, 'strings.xml'));
      if (!stringsFile.existsSync()) continue;

      final doc = tryParseXmlFile(stringsFile);
      if (doc == null) continue;

      final stale = doc.rootElement.childElements.where((e) {
        if (e.localName != 'string') return false;
        final name = e.getAttribute('name');
        if (name == null || !ownedPattern.hasMatch(name)) return false;
        return !live.contains(name);
      }).toList();
      if (stale.isEmpty) continue;

      for (final element in stale) {
        element.remove();
      }
      writeXmlFile(stringsFile, doc);
      logger.detail('Removed stale translations from ${stringsFile.path}');
    }
  }

  /// Removes the pre-`home_widget_` description entry this widget used to own.
  ///
  /// Narrowly matched by exact name: the provider XML now points at the
  /// prefixed entry, so the old one is dead. Anything else in the file, and any
  /// name that does not match exactly, is left alone.
  Future<void> _removeLegacyStringResource(
    Directory projectRoot, {
    required String name,
  }) async {
    final stringsFile = _stringsFile(projectRoot, null);
    if (!stringsFile.existsSync()) return;

    final doc = tryParseXmlFile(stringsFile);
    if (doc == null) return;

    final stale = doc.rootElement.childElements
        .where(
          (e) => e.localName == 'string' && e.getAttribute('name') == name,
        )
        .toList();
    if (stale.isEmpty) return;

    for (final element in stale) {
      element.remove();
    }
    writeXmlFile(stringsFile, doc);
    logger.detail('Removed legacy string resource "$name"');
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
