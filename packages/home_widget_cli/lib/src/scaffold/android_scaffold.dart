import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../util/android_package.dart';
import '../util/cli_io.dart';
import '../util/compose_kotlin_compat.dart';
import '../util/fs.dart';
import '../util/gradle_utils.dart';
import '../util/kotlin_version_detector.dart';
import '../util/naming.dart';
import '../util/xml_utils.dart';

final class AndroidWidgetScaffold {
  AndroidWidgetScaffold(
      {required this.projectRoot, required this.widgetClassName});

  final Directory projectRoot;
  final String widgetClassName;

  /// Create Android placeholders using Jetpack Compose (Glance) and wire them
  /// into Gradle/AndroidManifest in an idempotent way.
  Future<void> run() async {
    final androidAppDir = Directory(p.join(projectRoot.path, 'android', 'app'));
    if (!androidAppDir.existsSync()) {
      cliIO.writelnErr(
        'Warning: android/app/ not found. Skipping Android scaffolding.',
      );
      return;
    }

    final packageName = tryDetectAndroidPackage(projectRoot) ?? 'com.example';
    final packagePath = packageName.split('.').join(p.separator);

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

    final widgetFile = File(p.join(kotlinDir.path, '$widgetClassName.kt'));
    final receiverFile = File(
      p.join(kotlinDir.path, '${widgetClassName}Receiver.kt'),
    );
    final providerFile = File(
      p.join(kotlinDir.path, '${widgetClassName}Provider.kt'),
    );

    // `@xml/<name>` used in AndroidManifest receiver meta-data.
    final providerInfoName = toSnakeCase(widgetClassName);
    final providerInfoFile = File(
      p.join(resXmlDir.path, '$providerInfoName.xml'),
    );

    await ensureDir(kotlinDir);
    await ensureDir(resXmlDir);

    await writeFileIfMissing(
      widgetFile,
      _androidGlanceWidgetPlaceholder(
        packageName: packageName,
        widgetClassName: widgetClassName,
      ),
    );

    await writeFileIfMissing(
      receiverFile,
      _androidGlanceReceiverPlaceholder(
        packageName: packageName,
        widgetClassName: widgetClassName,
      ),
    );

    await writeFileIfMissing(
      providerFile,
      _androidHomeWidgetProviderPlaceholder(
        packageName: packageName,
        widgetClassName: widgetClassName,
      ),
    );

    await writeFileIfMissing(
      providerInfoFile,
      _androidAppWidgetProviderInfoPlaceholder(
        initialLayoutName: 'glance_default_loading_layout',
      ),
    );

    // Best-effort: wire up Gradle + AndroidManifest.xml.
    await _ensureAndroidGlanceGradleSetup(projectRoot);
    await _ensureAndroidManifestReceiver(
      projectRoot,
      widgetClassName: widgetClassName,
      appPackageName: packageName,
      providerInfoName: providerInfoName,
    );
  }
}

String _androidGlanceWidgetPlaceholder({
  required String packageName,
  required String widgetClassName,
}) {
  return '''
// GENERATED PLACEHOLDER by home_widget_cli
//
// This is a placeholder Glance (Jetpack Compose) widget.
// Next steps (manual):
// - Replace placeholder UI with your actual Compose/Glance UI.
//
// Data access (via home_widget):
// - This widget uses HomeWidgetGlanceStateDefinition(), so you can access the
//   SharedPreferences via:
//     val prefs = currentState<HomeWidgetGlanceState>().preferences
//     val counter = prefs.getInt("counter", 0)

package $packageName

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Box
import androidx.glance.state.currentState
import androidx.glance.text.Text
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

class $widgetClassName : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      // Example:
      // val prefs = currentState<HomeWidgetGlanceState>().preferences
      // val counter = prefs.getInt("counter", 0)
      Box(modifier = GlanceModifier.background(Color.White)) {
        Text(text = "$widgetClassName (placeholder)")
      }
    }
  }
}
''';
}

String _androidGlanceReceiverPlaceholder({
  required String packageName,
  required String widgetClassName,
}) {
  return '''
// GENERATED PLACEHOLDER by home_widget_cli
//
// This receiver is registered in AndroidManifest.xml by home_widget_cli
// (best-effort). If your manifest is non-standard, verify the entry was added
// or register it manually.
//
// Note: We extend HomeWidgetGlanceWidgetReceiver from home_widget so the plugin
// can keep the Glance state in sync for easier data access.

package $packageName

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ${widgetClassName}Receiver : HomeWidgetGlanceWidgetReceiver<$widgetClassName>() {
  override val glanceAppWidget = $widgetClassName()
}
''';
}

String _androidHomeWidgetProviderPlaceholder({
  required String packageName,
  required String widgetClassName,
}) {
  return '''
// GENERATED PLACEHOLDER by home_widget_cli
//
// Alternative (non-Glance) widget base class:
// If you prefer classic RemoteViews widgets (XML layouts), extend HomeWidgetProvider
// for easier data access:
//
//   override fun onUpdate(..., widgetData: SharedPreferences) {
//     val counter = widgetData.getInt("counter", 0)
//   }

package $packageName

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

class ${widgetClassName}Provider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    // TODO: Implement RemoteViews update here if you are not using Glance.
    // Example:
    // val counter = widgetData.getInt("counter", 0)
  }
}
''';
}

String _androidAppWidgetProviderInfoPlaceholder({
  required String initialLayoutName,
}) {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED PLACEHOLDER by home_widget_cli -->
<!--
  This file must be referenced from AndroidManifest.xml:
    <meta-data android:name="android.appwidget.provider" android:resource="@xml/<this_file_name>" />

  Replace placeholder values as needed.
-->
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/$initialLayoutName"
    android:minWidth="180dp"
    android:minHeight="80dp"
    android:updatePeriodMillis="0"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
''';
}

Future<void> _ensureAndroidGlanceGradleSetup(Directory projectRoot) async {
  const fallbackGlanceVersion = '1.0.0';
  final glanceVersion = await _tryResolveLatestAndroidxReleaseVersion(
        groupPath: 'androidx/glance',
        artifactId: 'glance-appwidget',
        major: 1,
      ) ??
      fallbackGlanceVersion;

  final kotlinVersion = tryDetectAndroidKotlinVersion(projectRoot);
  final composeCompilerVersion =
      kotlinVersion == null ? null : composeCompilerForKotlin(kotlinVersion);
  if (kotlinVersion != null && composeCompilerVersion == null) {
    final major = int.tryParse(kotlinVersion.split('.').first);
    // The official table currently covers Kotlin 1.x. For Kotlin 2.x, Compose
    // compiler integration is handled differently and the extension version is
    // often not required/used.
    if (major == null || major < 2) {
      cliIO.writelnErr(
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
      cliIO.writelnOut('Updated: ${gradleGroovy.path}');
    }
    return;
  }

  if (gradleKts.existsSync()) {
    final original = gradleKts.readAsStringSync();
    var updated = original;

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
      cliIO.writelnOut('Updated: ${gradleKts.path}');
    }
    return;
  }

  cliIO.writelnErr(
    'Warning: Could not find android/app/build.gradle(.kts); skipping Gradle '
    'Glance setup.',
  );
}

Future<void> _ensureAndroidManifestReceiver(
  Directory projectRoot, {
  required String widgetClassName,
  required String appPackageName,
  required String providerInfoName,
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
    cliIO.writelnErr(
      'Warning: android/app/src/main/AndroidManifest.xml not found; skipping '
      'manifest wiring.',
    );
    return;
  }

  final receiverFqcn = '$appPackageName.${widgetClassName}Receiver';

  final manifestXml = tryParseXmlFile(manifestFile);
  if (manifestXml == null) {
    cliIO.writelnErr(
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
    cliIO.writelnErr(
      'Warning: Could not find <application> in AndroidManifest.xml; skipping '
      'manifest wiring.',
    );
    return;
  }

  // Idempotency checks (cover existing receivers from older generators too).
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
    ),
  );

  writeXmlFile(manifestFile, manifestXml);
  cliIO.writelnOut('Updated: ${manifestFile.path}');
}

bool _androidApplicationHasWidgetReceiver(
  XmlElement application, {
  required String receiverFqcn,
  required String widgetClassName,
  required String providerInfoName,
}) {
  // Match by receiver name (exact or suffix), and also by provider meta-data
  // reference (covers older generators and custom receiver class names).
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
      (e) => e.getAttribute('android:resource') == '@xml/$providerInfoName');
  return hasProviderMeta;
}

XmlElement _buildAndroidAppWidgetReceiverElement({
  required String receiverFqcn,
  required String widgetClassName,
  required String providerInfoName,
}) {
  return XmlElement(
    XmlName('receiver'),
    [
      XmlAttribute(XmlName('android:name'), receiverFqcn),
      XmlAttribute(XmlName('android:label'), widgetClassName),
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
  );
}

Future<String?> _tryResolveLatestAndroidxReleaseVersion({
  required String groupPath,
  required String artifactId,
  required int major,
}) async {
  // Google Maven metadata (best-effort).
  final uri = Uri.parse(
    'https://dl.google.com/dl/android/maven2/$groupPath/$artifactId/maven-metadata.xml',
  );

  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/xml');
    final response = await request.close().timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      client.close(force: true);
      return null;
    }

    final body = await response.transform(utf8.decoder).join();
    client.close(force: true);

    // Prefer stable releases (no qualifiers), e.g. "1.2.3".
    //
    // Parse structured XML instead of regex.
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
  } catch (_) {
    return null;
  }
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
