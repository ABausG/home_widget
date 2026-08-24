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
///
/// [handleLocaleChange] adds `android.intent.action.LOCALE_CHANGED` to the
/// receiver's intent-filter so a placed widget re-renders after a system
/// language change. Set it for widgets that render localized content
/// themselves.
Future<void> ensureAndroidManifestReceiver(
  Directory projectRoot, {
  required String widgetClassName,
  required String appPackageName,
  required String providerInfoName,
  bool handleLocaleChange = false,
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

  final existing = _findAndroidWidgetReceiver(
    application,
    receiverFqcn: receiverFqcn,
    widgetClassName: widgetClassName,
    providerInfoName: providerInfoName,
  );

  if (existing != null) {
    var changed = false;

    // Never downgrade a label the caller did not ask about: without the
    // fallback to the current attribute, a call that omits [label] would
    // rewrite an existing `@string/…` resource reference to the bare class
    // name.
    final desiredLabel =
        label ?? existing.getAttribute('android:label') ?? widgetClassName;
    final currentLabel = existing.getAttribute('android:label');
    if (currentLabel != desiredLabel) {
      existing.setAttribute('android:label', desiredLabel);
      changed = true;
    }

    if (handleLocaleChange && _ensureLocaleChangedAction(existing)) {
      changed = true;
    }
    // Deliberately add-only: a widget that stops being localized keeps the
    // action, since removing it would mean deciding whether a hand-written
    // entry was ours to delete.

    if (changed) {
      writeXmlFile(manifestFile, manifestXml);
      logger.detail('Updated: ${manifestFile.path}');
    }
    return;
  }

  application.children.add(
    _buildAndroidAppWidgetReceiverElement(
      receiverFqcn: receiverFqcn,
      widgetClassName: widgetClassName,
      providerInfoName: providerInfoName,
      handleLocaleChange: handleLocaleChange,
      label: label,
    ),
  );

  writeXmlFile(manifestFile, manifestXml);
  logger.detail('Updated: ${manifestFile.path}');
}

/// Returns the matching widget `<receiver>`, or null when none is registered.
XmlElement? _findAndroidWidgetReceiver(
  XmlElement application, {
  required String receiverFqcn,
  required String widgetClassName,
  required String providerInfoName,
}) {
  // Match the class name as a whole trailing segment — fully qualified
  // (`com.pkg.FooReceiver`), relative (`.FooReceiver`) or bare (`FooReceiver`).
  // A substring check would be wrong: `GreetingHomeWidgetReceiver` is contained
  // in `AdaptiveGreetingHomeWidgetReceiver`, so one widget would find and
  // mutate another widget's receiver.
  final receiverClassPattern = RegExp(
    '(^|\\.)${RegExp.escape('${widgetClassName}Receiver')}\$',
  );

  for (final receiver
      in application.childElements.where((e) => e.localName == 'receiver')) {
    final name = receiver.getAttribute('android:name');
    if (name == null) continue;
    if (name == receiverFqcn || receiverClassPattern.hasMatch(name)) {
      return receiver;
    }
  }

  for (final receiver
      in application.childElements.where((e) => e.localName == 'receiver')) {
    final hasProviderMeta = receiver.findAllElements('meta-data').any(
          (e) => e.getAttribute('android:resource') == '@xml/$providerInfoName',
        );
    if (hasProviderMeta) return receiver;
  }

  return null;
}

const String _appWidgetUpdateAction =
    'android.appwidget.action.APPWIDGET_UPDATE';
const String _localeChangedAction = 'android.intent.action.LOCALE_CHANGED';

XmlElement _actionElement(String name) => XmlElement(
      XmlName('action'),
      [XmlAttribute(XmlName('android:name'), name)],
      const [],
    );

/// Adds `LOCALE_CHANGED` to [receiver]'s intent-filter if it is not there yet.
///
/// Returns whether the document was modified, so the caller only rewrites the
/// manifest when something actually changed.
bool _ensureLocaleChangedAction(XmlElement receiver) {
  final alreadyPresent = receiver
      .findAllElements('action')
      .any((e) => e.getAttribute('android:name') == _localeChangedAction);
  if (alreadyPresent) return false;

  final filter = receiver.childElements
      .where((e) => e.localName == 'intent-filter')
      .cast<XmlElement?>()
      .firstWhere((e) => e != null, orElse: () => null);

  if (filter == null) {
    // Giving a component its first intent-filter makes `android:exported`
    // mandatory on API 31+: a component with an intent-filter that does not
    // declare it fails to build/install. A hand-written receiver adopted by
    // name match may not declare it, so supply the same default as a
    // generated receiver — but never overwrite an explicit author choice.
    // (This is purely about the manifest merger's requirement; system
    // broadcasts such as LOCALE_CHANGED are delivered either way.)
    if (receiver.getAttribute('android:exported') == null) {
      receiver.setAttribute('android:exported', 'true');
    }
    receiver.children.add(
      XmlElement(
        XmlName('intent-filter'),
        const [],
        [_actionElement(_localeChangedAction)],
      ),
    );
    return true;
  }

  filter.children.add(_actionElement(_localeChangedAction));
  return true;
}

XmlElement _buildAndroidAppWidgetReceiverElement({
  required String receiverFqcn,
  required String widgetClassName,
  required String providerInfoName,
  bool handleLocaleChange = false,
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
          _actionElement(_appWidgetUpdateAction),
          if (handleLocaleChange) _actionElement(_localeChangedAction),
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
