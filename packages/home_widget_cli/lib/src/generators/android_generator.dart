import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import '../util/android_package.dart';
import '../util/android_templates.dart';
import '../util/android_wiring.dart';
import '../util/logger.dart';
import '../util/fs.dart';
import '../util/naming.dart';

class AndroidGenerator {
  final WidgetSpec spec;
  final Directory projectRoot;

  AndroidGenerator({
    required this.spec,
    required this.projectRoot,
  });

  Future<void> generate() async {
    final androidAppDir = Directory(p.join(projectRoot.path, 'android', 'app'));
    if (!androidAppDir.existsSync()) {
      logger.warn(
        'Warning: android/app/ not found. Skipping Android generation for ${spec.name}.',
      );
      return;
    }

    // 1. Determine package name (annotation override or auto-detect)
    final packageName = spec.android?.packageName ??
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
    await widgetFile.writeAsString(
      androidGlanceWidgetTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
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

// Minimal HttpClient logic if we really wanted version resolution, but kept hardcoded above.
