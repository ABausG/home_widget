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

    // Falling back to the current attribute keeps a call that omits [label]
    // from downgrading an existing `@string/…` reference to the class name.
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
    // Add-only: the action is never removed again, since it may be
    // hand-written.

    if (changed && writeXmlFile(manifestFile, manifestXml)) {
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

  if (writeXmlFile(manifestFile, manifestXml)) {
    logger.detail('Updated: ${manifestFile.path}');
  }
}

/// Fully qualified name of the plugin receiver that re-broadcasts scheduled
/// widget updates and re-arms alarms after a reboot or app update.
const String scheduledUpdateReceiverFqcn =
    'es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver';

/// Ensures the app manifest declares everything `HomeWidget.scheduleWidgetUpdates`
/// needs on Android.
///
/// The plugin ships the receiver class but deliberately does not register it in
/// its own manifest (that would add `RECEIVE_BOOT_COMPLETED` to every app using
/// `home_widget`), so apps with time-based widget content must declare it
/// themselves:
///
/// - `android.permission.RECEIVE_BOOT_COMPLETED`
/// - a non-exported receiver for [scheduledUpdateReceiverFqcn] handling
///   `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` and
///   `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`
///
/// Idempotent: an existing permission declaration is left untouched. An
/// existing receiver declaration is left untouched except that a missing
/// `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` action is added to it (the
/// same add-only pattern [ensureAndroidManifestReceiver] uses for
/// `LOCALE_CHANGED`), so apps generated before that action existed pick it up.
/// Only called for specs that actually have time-based fields, so manifests of
/// other projects stay byte-identical.
Future<void> ensureAndroidManifestScheduledUpdates(
  Directory projectRoot,
) async {
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
      'scheduled update wiring. Time-based widget content will not update on '
      'Android until the HomeWidgetScheduledUpdateReceiver is registered.',
    );
    return;
  }

  final manifestXml = tryParseXmlFile(manifestFile);
  if (manifestXml == null) {
    logger.warn(
      'Warning: Could not parse AndroidManifest.xml as XML; skipping scheduled '
      'update wiring.',
    );
    return;
  }

  final manifest = manifestXml.rootElement;
  final application = manifest.childElements
      .where((e) => e.localName == 'application')
      .cast<XmlElement?>()
      .firstWhere((e) => e != null, orElse: () => null);

  if (application == null) {
    logger.warn(
      'Warning: Could not find <application> in AndroidManifest.xml; skipping '
      'scheduled update wiring.',
    );
    return;
  }

  var changed = false;

  const bootPermission = 'android.permission.RECEIVE_BOOT_COMPLETED';
  final hasBootPermission = manifest.childElements
      .where((e) => e.localName == 'uses-permission')
      .any((e) => e.getAttribute('android:name') == bootPermission);
  if (!hasBootPermission) {
    manifest.children.insert(
      0,
      XmlElement(
        XmlName('uses-permission'),
        [XmlAttribute(XmlName('android:name'), bootPermission)],
        const [],
      ),
    );
    changed = true;
  }

  final existingReceiver = application.childElements
      .where((e) => e.localName == 'receiver')
      .cast<XmlElement?>()
      .firstWhere(
        (e) => e!.getAttribute('android:name') == scheduledUpdateReceiverFqcn,
        orElse: () => null,
      );
  if (existingReceiver == null) {
    application.children.add(_buildScheduledUpdateReceiverElement());
    changed = true;
  } else if (_ensureExactAlarmPermissionStateChangedAction(existingReceiver)) {
    // Add-only: picks up apps generated before this action existed. The
    // action is never removed again, since the intent-filter may be
    // hand-edited.
    changed = true;
  }

  if (!changed) return;

  writeXmlFile(manifestFile, manifestXml);
  logger.detail('Updated: ${manifestFile.path}');
}

/// Action the plugin puts on the intent a widget click starts the app with.
///
/// The activity has to declare it, or Android delivers the click as a plain
/// launch and the URL never reaches the app.
const String homeWidgetLaunchAction = 'es.antonborri.home_widget.action.LAUNCH';

/// Ensures the app's launcher activity accepts the intent a widget click
/// sends, which is what makes the widget URL reach the app.
///
/// Idempotent: an activity already declaring [homeWidgetLaunchAction] is left
/// untouched. Only called for specs that configure a widget URL, so manifests
/// of other projects stay byte-identical.
Future<void> ensureAndroidManifestLaunchIntent(Directory projectRoot) async {
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
      'widget launch wiring. Tapping the widget will not hand the widget URL '
      'to the app.',
    );
    return;
  }

  final manifestXml = tryParseXmlFile(manifestFile);
  if (manifestXml == null) {
    logger.warn(
      'Warning: Could not parse AndroidManifest.xml as XML; skipping widget '
      'launch wiring.',
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
      'widget launch wiring.',
    );
    return;
  }

  final activities =
      application.childElements.where((e) => e.localName == 'activity');

  final alreadyDeclared = activities.any(
    (activity) => activity
        .findAllElements('action')
        .any((e) => e.getAttribute('android:name') == homeWidgetLaunchAction),
  );
  if (alreadyDeclared) return;

  final launcher = activities.cast<XmlElement?>().firstWhere(
        (activity) => isAndroidLauncherActivity(activity!),
        orElse: () => null,
      );
  if (launcher == null) {
    logger.warn(
      'Warning: Could not find the launcher activity in AndroidManifest.xml; '
      'skipping widget launch wiring. Tapping the widget will not hand the '
      'widget URL to the app.',
    );
    return;
  }

  launcher.children.add(
    XmlElement(
      XmlName('intent-filter'),
      const [],
      [_actionElement(homeWidgetLaunchAction)],
    ),
  );

  if (writeXmlFile(manifestFile, manifestXml)) {
    logger.detail('Updated: ${manifestFile.path}');
  }
}

/// Broadcast the system sends to manifest-declared receivers (API 31+) when
/// `SCHEDULE_EXACT_ALARM` is granted, including re-granted after the user
/// revoked it. Revoking the permission makes the system delete the app's
/// exact alarms outright; re-arming them then relies on this broadcast (or
/// the next reboot) since nothing else signals the app.
const String _scheduleExactAlarmPermissionStateChangedAction =
    'android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED';

XmlElement _buildScheduledUpdateReceiverElement() {
  return XmlElement(
    XmlName('receiver'),
    [
      XmlAttribute(XmlName('android:name'), scheduledUpdateReceiverFqcn),
      XmlAttribute(XmlName('android:exported'), 'false'),
    ],
    [
      XmlElement(
        XmlName('intent-filter'),
        const [],
        [
          for (final action in const [
            'android.intent.action.BOOT_COMPLETED',
            'android.intent.action.MY_PACKAGE_REPLACED',
            _scheduleExactAlarmPermissionStateChangedAction,
          ])
            XmlElement(
              XmlName('action'),
              [XmlAttribute(XmlName('android:name'), action)],
              const [],
            ),
        ],
      ),
    ],
    false,
  );
}

/// Adds `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` to [receiver]'s
/// intent-filter if it is not there yet.
///
/// Returns whether the document was modified.
bool _ensureExactAlarmPermissionStateChangedAction(XmlElement receiver) {
  final alreadyPresent = receiver.findAllElements('action').any(
        (e) =>
            e.getAttribute('android:name') ==
            _scheduleExactAlarmPermissionStateChangedAction,
      );
  if (alreadyPresent) return false;

  final filter = receiver.childElements
      .where((e) => e.localName == 'intent-filter')
      .cast<XmlElement?>()
      .firstWhere((e) => e != null, orElse: () => null);

  if (filter == null) {
    // Giving a component its first intent-filter makes `android:exported`
    // mandatory on API 31+. A hand-written receiver adopted by name match may
    // not declare it, so supply the same default a generated receiver gets —
    // never overwriting an explicit choice.
    if (receiver.getAttribute('android:exported') == null) {
      receiver.setAttribute('android:exported', 'false');
    }
    receiver.children.add(
      XmlElement(
        XmlName('intent-filter'),
        const [],
        [_actionElement(_scheduleExactAlarmPermissionStateChangedAction)],
      ),
    );
    return true;
  }

  filter.children.add(
    _actionElement(_scheduleExactAlarmPermissionStateChangedAction),
  );
  return true;
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
/// Returns whether the document was modified.
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
    // mandatory on API 31+: without it the build/install fails. A hand-written
    // receiver adopted by name match may not declare it, so supply the same
    // default a generated receiver gets — never overwriting an explicit choice.
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
