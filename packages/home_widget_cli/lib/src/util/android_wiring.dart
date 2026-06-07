import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'logger.dart';
import 'compose_kotlin_compat.dart';
import 'gradle_utils.dart';
import 'kotlin_version_detector.dart';
import 'xml_utils.dart';

/// Ensures the Android project is set up for Glance (Jetpack Compose) widgets.
///
/// Updates `build.gradle` or `build.gradle.kts` to include:
/// - `androidx.glance:glance-appwidget` dependency
/// - Compose build features
/// - Kotlin Compose Compiler extension (if needed)
Future<void> ensureAndroidGlanceGradleSetup(Directory projectRoot) async {
  const fallbackGlanceVersion = '1.1.0';
  final glanceVersion = await _tryResolveLatestAndroidxReleaseVersion(
        groupPath: 'androidx/glance',
        artifactId: 'glance-appwidget',
        major: 1,
      ) ??
      fallbackGlanceVersion;

  final kotlinVersion = tryDetectAndroidKotlinVersion(projectRoot);
  final composeCompilerVersion =
      kotlinVersion == null ? null : composeCompilerForKotlin(kotlinVersion);
  final kotlinMajor = kotlinVersion == null
      ? null
      : int.tryParse(kotlinVersion.split('.').first);

  if (kotlinVersion != null && composeCompilerVersion == null) {
    if (kotlinMajor == null || kotlinMajor < 2) {
      logger.warn(
        'Warning: Detected Kotlin $kotlinVersion, but could not determine a '
        'compatible Compose compiler version from the compatibility table. '
        'Skipping composeOptions.kotlinCompilerExtensionVersion insertion.',
      );
    }
  }

  final gradleGroovy = File(
    p.join(projectRoot.path, 'android', 'app', 'build.gradle'),
  );
  final gradleKts = File(
    p.join(projectRoot.path, 'android', 'app', 'build.gradle.kts'),
  );

  if (gradleGroovy.existsSync()) {
    final original = gradleGroovy.readAsStringSync();
    var updated = original;

    if (kotlinMajor != null && kotlinMajor >= 2) {
      updated = ensureKotlinComposeCompilerPlugin(
        updated,
        dialect: GradleDialect.groovy,
        kotlinVersion: kotlinVersion!,
      );
    }
    updated = ensureGlanceDependency(
      updated,
      dialect: GradleDialect.groovy,
      glanceVersion: glanceVersion,
    );
    updated = ensureComposeEnabled(
      updated,
      dialect: GradleDialect.groovy,
      kotlinCompilerExtensionVersion: composeCompilerVersion,
    );

    if (updated != original) {
      gradleGroovy.writeAsStringSync(updated);
      logger.detail('Updated: ${gradleGroovy.path}');
    }
    return;
  }

  if (gradleKts.existsSync()) {
    final original = gradleKts.readAsStringSync();
    var updated = original;

    if (kotlinMajor != null && kotlinMajor >= 2) {
      updated = ensureKotlinComposeCompilerPlugin(
        updated,
        dialect: GradleDialect.kts,
        kotlinVersion: kotlinVersion!,
      );
    }
    updated = ensureGlanceDependency(
      updated,
      dialect: GradleDialect.kts,
      glanceVersion: glanceVersion,
    );
    updated = ensureComposeEnabled(
      updated,
      dialect: GradleDialect.kts,
      kotlinCompilerExtensionVersion: composeCompilerVersion,
    );

    if (updated != original) {
      gradleKts.writeAsStringSync(updated);
      logger.detail('Updated: ${gradleKts.path}');
    }
    return;
  }

  // If neither exists, we can't do anything (unlikely in a Flutter project).
  logger.warn(
    'Warning: Could not find android/app/build.gradle(.kts); skipping Gradle '
    'Glance setup.',
  );
}

/// Ensures the widget receiver is registered in `AndroidManifest.xml`.
Future<void> ensureAndroidManifestReceiver(
  Directory projectRoot, {
  required String widgetClassName,
  required String appPackageName,
  required String providerInfoName,
  String? label,
}) async {
  final manifestFile = File(
    p.join(
      projectRoot.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  if (!manifestFile.existsSync()) {
    logger.warn(
      'Warning: android/app/src/main/AndroidManifest.xml not found; skipping '
      'manifest wiring.',
    );
    return;
  }

  final receiverFqcn = '$appPackageName.${widgetClassName}Receiver';

  final manifestXml = tryParseXmlFile(manifestFile);
  if (manifestXml == null) {
    logger.warn(
      'Warning: Could not parse AndroidManifest.xml as XML; skipping manifest '
      'wiring.',
    );
    return;
  }

  final application = manifestXml.rootElement.childElements
      .where((e) => e.localName == 'application')
      .cast<XmlElement?>()
      .firstWhere((e) => e != null, orElse: () => null);

  if (application == null) {
    logger.warn(
      'Warning: Could not find <application> in AndroidManifest.xml; skipping '
      'manifest wiring.',
    );
    return;
  }

  if (_androidApplicationHasWidgetReceiver(
    application,
    receiverFqcn: receiverFqcn,
    widgetClassName: widgetClassName,
    providerInfoName: providerInfoName,
  )) {
    return;
  }

  application.children.add(
    _buildAndroidAppWidgetReceiverElement(
      receiverFqcn: receiverFqcn,
      widgetClassName: widgetClassName,
      providerInfoName: providerInfoName,
      label: label,
    ),
  );

  writeXmlFile(manifestFile, manifestXml);
  logger.detail('Updated: ${manifestFile.path}');
}

bool _androidApplicationHasWidgetReceiver(
  XmlElement application, {
  required String receiverFqcn,
  required String widgetClassName,
  required String providerInfoName,
}) {
  final hasReceiverName = application.childElements
      .where((e) => e.localName == 'receiver')
      .any((receiver) {
    final name = receiver.getAttribute('android:name');
    if (name == null) return false;
    if (name == receiverFqcn) return true;
    return name.contains('${widgetClassName}Receiver');
  });
  if (hasReceiverName) return true;

  final hasProviderMeta = application.findAllElements('meta-data').any(
        (e) => e.getAttribute('android:resource') == '@xml/$providerInfoName',
      );
  return hasProviderMeta;
}

XmlElement _buildAndroidAppWidgetReceiverElement({
  required String receiverFqcn,
  required String widgetClassName,
  required String providerInfoName,
  String? label,
}) {
  return XmlElement(
    XmlName('receiver'),
    [
      XmlAttribute(XmlName('android:name'), receiverFqcn),
      XmlAttribute(XmlName('android:label'), label ?? widgetClassName),
      XmlAttribute(XmlName('android:exported'), 'true'),
    ],
    [
      XmlElement(
        XmlName('intent-filter'),
        const [],
        [
          XmlElement(
            XmlName('action'),
            [
              XmlAttribute(
                XmlName('android:name'),
                'android.appwidget.action.APPWIDGET_UPDATE',
              ),
            ],
            const [],
          ),
        ],
      ),
      XmlElement(
        XmlName('meta-data'),
        [
          XmlAttribute(XmlName('android:name'), 'android.appwidget.provider'),
          XmlAttribute(
            XmlName('android:resource'),
            '@xml/$providerInfoName',
          ),
        ],
        const [],
      ),
    ],
    false,
  );
}

Future<String?> _tryResolveLatestAndroidxReleaseVersion({
  required String groupPath,
  required String artifactId,
  required int major,
}) async {
  final uri = Uri.parse(
    'https://dl.google.com/dl/android/maven2/$groupPath/$artifactId/maven-metadata.xml',
  );

  // coverage:ignore-start
  try {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 4);

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/xml');
      final response =
          await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();

      final versions = <String>[];
      try {
        final doc = XmlDocument.parse(body);
        versions.addAll(
          doc
              .findAllElements('version')
              .map((e) => e.innerText.trim())
              .where((v) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v))
              .where((v) => v.startsWith('$major.')),
        );
      } catch (_) {
        versions.addAll(
          RegExp(r'<version>([^<]+)</version>')
              .allMatches(body)
              .map((m) => m.group(1))
              .whereType<String>()
              .map((v) => v.trim())
              .where((v) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v))
              .where((v) => v.startsWith('$major.')),
        );
      }

      if (versions.isEmpty) return null;
      versions.sort(_compareDottedInts3);
      return versions.last;
    } finally {
      client.close(force: true);
    }
  } catch (_) {
    return null;
  }
  // coverage:ignore-end
}

int _compareDottedInts3(String a, String b) {
  List<int> parse(String s) =>
      s.split('.').map(int.parse).toList(growable: false);
  final ap = parse(a);
  final bp = parse(b);
  for (var i = 0; i < 3; i++) {
    final diff = ap[i].compareTo(bp[i]);
    if (diff != 0) return diff;
  }
  return 0;
}
