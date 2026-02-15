import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import '../util/android_package.dart';
import '../util/android_templates.dart';
import '../util/android_wiring.dart';
import '../util/logger.dart';
import '../util/fs.dart';
import '../util/naming.dart';

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

    // 1. Determine package name (annotation override or auto-detect)
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

    // 2. Generate Widget.kt
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
        '        fun fromPreferences(prefs: android.content.SharedPreferences): $className {',
      );
      buffer.writeln('            return $className(');

      for (final field in spec.dataFields) {
        final key = field.key;
        String readLogic;
        switch (field.type) {
          case HWDataFieldType.string:
            readLogic = 'prefs.getString("$key", null)';
            break;
          case HWDataFieldType.int_:
            readLogic =
                'if (prefs.contains("$key")) prefs.getInt("$key", 0) else null';
            break;
          case HWDataFieldType.double_:
            readLogic =
                'if (prefs.contains("$key")) prefs.getFloat("$key", 0f).toDouble() else null';
            break;
          case HWDataFieldType.bool_:
            readLogic =
                'if (prefs.contains("$key")) prefs.getBoolean("$key", false) else null';
            break;
        }

        buffer.writeln('                ${field.key} = $readLogic,');
      }

      buffer.writeln('            )');
      buffer.writeln('        }');
      buffer.writeln('    }');
      buffer.writeln('}');
      dataClassContent = buffer.toString();

      final bodyBuffer = StringBuffer();
      bodyBuffer.writeln('    val prefs = currentState.preferences');
      bodyBuffer.writeln('    val data = $className.fromPreferences(prefs)');
      bodyBuffer.writeln(
        '    Box(modifier = GlanceModifier.fillMaxSize().background(Color.White)) {',
      );
      bodyBuffer.writeln('      androidx.glance.layout.Column {');
      bodyBuffer.writeln('        Text(text = "$widgetClassName")');
      for (final field in spec.dataFields) {
        bodyBuffer.writeln(
          '        Text(text = "${field.key}: \${data.${field.key} ?: "-"}")',
        );
      }
      bodyBuffer.writeln('      }');
      bodyBuffer.writeln('    }');
      contentBody = bodyBuffer.toString();
    }

    await widgetFile.writeAsString(
      androidGlanceWidgetTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
        contentBody: contentBody,
        extraContent: dataClassContent,
      ),
    );
    logger.success('Generated: ${widgetFile.path}');

    // 3. Generate Receiver.kt
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

    // 4. Generate provider info XML
    final providerInfoFile = File(
      p.join(resXmlDir.path, '$providerInfoName.xml'),
    );
    await providerInfoFile.writeAsString(
      androidAppWidgetProviderInfoTemplate(
        initialLayoutName: 'glance_default_loading_layout',
      ),
    );
    logger.success('Generated: ${providerInfoFile.path}');

    // 5. Wire into Gradle and AndroidManifest (idempotent)
    await ensureAndroidGlanceGradleSetup(projectRoot);
    await ensureAndroidManifestReceiver(
      projectRoot,
      widgetClassName: widgetClassName,
      appPackageName: packageName,
      providerInfoName: providerInfoName,
    );
  }
}
