import 'dart:io';

import 'package:home_widget_generator/home_widget_generator_cli.dart';
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

    if (spec.dataFields.isNotEmpty) {
      final className = '${spec.className}Data';
      final buffer = StringBuffer();
      buffer.writeln('data class $className(');
      for (final field in spec.dataFields) {
        final type = field.type.kotlinType;
        buffer.writeln('    val ${field.key}: $type? = null,');
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

      for (final field in spec.dataFields) {
        final readLogic = field.type.androidReadValue(
          store: 'prefs',
          key: '\${PREFERENCES_PREFIX}.${field.key}',
        );
        buffer.writeln('                ${field.key} = $readLogic,');
      }

      buffer.writeln('            )');
      buffer.writeln('        }');
      buffer.writeln('    }');
      buffer.writeln('}');
      dataClassContent = buffer.toString();
    }

    final bodyBuffer = StringBuffer();
    if (spec.dataFields.isNotEmpty) {
      final className = '${spec.className}Data';
      bodyBuffer.writeln('    val prefs = currentState.preferences');
      bodyBuffer
          .writeln('    val widgetData = $className.fromPreferences(prefs)');
    }

    final useTheme = spec.data.android?.useGlanceTheme ?? true;
    final bgColor = spec.data.android?.backgroundColor;

    var widgetTreeBody = emitKotlinWidgetBody(
      spec.effectiveWidgetTree,
      dataExpr: spec.dataFields.isNotEmpty ? 'widgetData' : 'null',
      indent: useTheme ? 3 : 2, // inside WidgetContent, +1 if in GlanceTheme
    );

    if (bgColor != null) {
      widgetTreeBody = injectGlanceModifier(
        widgetTreeBody,
        'background(${bgColor.toKotlin(0, dataExpr: spec.dataFields.isNotEmpty ? "widgetData" : "null")})',
      );
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
    logger.success('Generated: ${widgetFile.path}');

    final receiverFile = File(
      p.join(kotlinDir.path, '${widgetClassName}Receiver.kt'),
    );
    await receiverFile.writeAsString(
      androidGlanceReceiverTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
      ),
    );
    logger.success('Generated: ${receiverFile.path}');

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
        minWidth: android?.minWidth ?? 180,
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
    logger.success('Generated: ${providerInfoFile.path}');

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
    if (doc == null) return;

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
    logger.info('Updated: ${stringsFile.path}');
  }
}
