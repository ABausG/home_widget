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

    final androidAppDir = Directory(p.join(projectRoot.path, 'android', 'app'));
    if (!androidAppDir.existsSync()) {
      logger.warn(
        'Warning: android/app/ not found. Skipping Android generation for ${spec.data.name}.',
      );
      return;
    }

    final packageName = spec.data.android?.packageName ??
        tryDetectAndroidPackage(projectRoot) ??
        'com.example';
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
      buffer.writeln(
        '        fun fromPreferences(prefs: android.content.SharedPreferences): $className {',
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
    final bodyBuffer = StringBuffer();
    if (hasDataFields) {
      final className = '${spec.className}Data';
      bodyBuffer.writeln('    val prefs = currentState.preferences');
      bodyBuffer
          .writeln('    val widgetData = $className.fromPreferences(prefs)');
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
    String? descriptionResource;

    if (spec.data.description != null && spec.data.description!.isNotEmpty) {
      final descName = '${providerInfoName}_description';
      await _ensureStringResource(
        projectRoot,
        name: descName,
        value: spec.data.description!,
      );
      descriptionResource = '@string/$descName';
    }

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
      label: spec.data.name,
    );
  }

  Future<void> _ensureStringResource(
    Directory projectRoot, {
    required String name,
    required String value,
  }) async {
    final stringsFile = File(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'res',
        'values',
        'strings.xml',
      ),
    );

    if (!stringsFile.existsSync()) {
      await stringsFile.create(recursive: true);
      final doc = XmlDocument([
        XmlProcessing('xml', 'version="1.0" encoding="utf-8"'),
        XmlElement(XmlName('resources'), const [], [
          XmlElement(
            XmlName('string'),
            [XmlAttribute(XmlName('name'), name)],
            [XmlText(value)],
          ),
        ]),
      ]);
      writeXmlFile(stringsFile, doc);
      return;
    }

    final doc = tryParseXmlFile(stringsFile);
    if (doc == null) {
      // coverage:ignore-start
      return;
      // coverage:ignore-end
    }

    final resources = doc.rootElement;
    final existing = resources.childElements.where(
      (e) => e.localName == 'string' && e.getAttribute('name') == name,
    );
    if (existing.isNotEmpty) return;

    resources.children.add(
      XmlElement(
        XmlName('string'),
        [XmlAttribute(XmlName('name'), name)],
        [XmlText(value)],
      ),
    );

    writeXmlFile(stringsFile, doc);
    logger.detail('Updated: ${stringsFile.path}');
  }

  String _kotlinDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return 'null';
    if (defaultValue is String) {
      return '"${defaultValue.replaceAll(r'$', r'\$')}"';
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
