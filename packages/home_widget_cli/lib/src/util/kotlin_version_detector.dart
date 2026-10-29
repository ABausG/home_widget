import 'dart:io';

import 'package:path/path.dart' as p;

/// Best-effort detection of the Kotlin Gradle plugin version used by a Flutter
/// Android project.
///
/// This is intentionally conservative and pattern-based (no full Gradle AST).
/// It tries common Flutter/AGP layouts:
/// - `android/build.gradle` / `android/build.gradle.kts`
/// - `android/settings.gradle` / `android/settings.gradle.kts`
/// - `android/gradle/libs.versions.toml`
String? tryDetectAndroidKotlinVersion(Directory projectRoot) {
  final androidDir = Directory(p.join(projectRoot.path, 'android'));
  if (!androidDir.existsSync()) return null;

  String? fromFile(String relPath) {
    final f = File(p.join(projectRoot.path, relPath));
    if (!f.existsSync()) return null;
    try {
      return _extractKotlinVersion(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  // Common Flutter templates.
  final candidates = <String?>[
    fromFile(p.join('android', 'build.gradle')),
    fromFile(p.join('android', 'build.gradle.kts')),
    fromFile(p.join('android', 'settings.gradle')),
    fromFile(p.join('android', 'settings.gradle.kts')),
    fromFile(p.join('android', 'gradle', 'libs.versions.toml')),
  ];

  for (final v in candidates) {
    if (v != null) return v;
  }
  return null;
}

String? _extractKotlinVersion(String text) {
  // 1) Old style: ext.kotlin_version = '1.9.10'
  //    or: ext.kotlin_version = "1.9.10"
  final ext = RegExp(
    '(?:ext\\.)?kotlin[_-]version\\s*=\\s*[\'"](\\d+\\.\\d+\\.\\d+)[\'"]',
  ).firstMatch(text);
  if (ext != null) return ext.group(1);

  // 2) Plugin DSL (Groovy):
  //    id "org.jetbrains.kotlin.android" version "1.9.10" apply false
  final pluginGroovy = RegExp(
    'id\\s+[\'"]org\\.jetbrains\\.kotlin\\.(?:android|jvm|multiplatform)[\'"]\\s+version\\s+[\'"](\\d+\\.\\d+\\.\\d+)[\'"]',
  ).firstMatch(text);
  if (pluginGroovy != null) return pluginGroovy.group(1);

  // 3) Plugin DSL (KTS):
  //    id("org.jetbrains.kotlin.android") version "1.9.10" apply false
  final pluginKts = RegExp(
    'id\\(\\s*[\'"]org\\.jetbrains\\.kotlin\\.(?:android|jvm|multiplatform)[\'"]\\s*\\)\\s+version\\s+[\'"](\\d+\\.\\d+\\.\\d+)[\'"]',
  ).firstMatch(text);
  if (pluginKts != null) return pluginKts.group(1);

  // 4) libs.versions.toml (common in newer templates):
  //    kotlin = "1.9.10"
  final toml = RegExp(
    'kotlin\\w*\\s*=\\s*"(\\d+\\.\\d+\\.\\d+)"',
  ).firstMatch(text);
  if (toml != null) return toml.group(1);

  return null;
}
