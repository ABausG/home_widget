import 'dart:io';

import 'package:path/path.dart' as p;

import 'xml_utils.dart';

/// Attempts to detect the Android package name from common Flutter Android files.
///
/// Returns `null` if no package name could be detected.
String? tryDetectAndroidPackage(Directory projectRoot) {
  // 1) AndroidManifest.xml package="..."
  final manifest = File(
    p.join(
      projectRoot.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  final manifestPackage = _tryReadPackageFromManifest(manifest);
  if (manifestPackage != null) return manifestPackage;

  // 2) android/app/build.gradle(.kts) applicationId "..."
  final gradleGroovy = File(
    p.join(projectRoot.path, 'android', 'app', 'build.gradle'),
  );
  final gradleKts = File(
    p.join(projectRoot.path, 'android', 'app', 'build.gradle.kts'),
  );
  final gradlePackage = _tryReadApplicationIdFromGradle(gradleGroovy) ??
      _tryReadApplicationIdFromGradle(gradleKts);
  if (gradlePackage != null) return gradlePackage;

  // 3) (Fallback) android/app/src/main/kotlin/... first directory chain
  final kotlinMain = Directory(
    p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  final inferred = _tryInferPackageFromKotlinDir(kotlinMain);
  return inferred;
}

String? _tryReadPackageFromManifest(File manifest) {
  if (!manifest.existsSync()) return null;
  final xml = tryParseXmlFile(manifest);
  final pkg = xml?.rootElement.getAttribute('package');
  if (pkg != null && pkg.trim().isNotEmpty) return pkg.trim();

  // Fallback for malformed XML / unexpected formats.
  final text = manifest.readAsStringSync();
  final match = RegExp(r'package\s*=\s*"([^"]+)"').firstMatch(text);
  return match?.group(1);
}

/// Attempts to detect the fully qualified name of the activity the launcher
/// starts, which is the activity a widget click has to open.
///
/// Reads the `AndroidManifest.xml` activity whose intent-filter carries
/// `android.intent.action.MAIN` and `android.intent.category.LAUNCHER`. A
/// relative `android:name` (`.MainActivity`, `MainActivity`) is resolved the
/// way Android resolves it: against the manifest `package`, falling back to the
/// detected application id — never against a codegen package override, which
/// names where generated files are written, not where the app's classes live.
/// Returns `null` when no launcher activity is declared, or when a relative
/// name cannot be resolved.
String? tryDetectAndroidLauncherActivity(Directory projectRoot) {
  final manifest = File(
    p.join(
      projectRoot.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  if (!manifest.existsSync()) return null;

  final xml = tryParseXmlFile(manifest);
  if (xml == null) return null;

  for (final application in xml.rootElement.childElements
      .where((e) => e.localName == 'application')) {
    for (final activity
        in application.childElements.where((e) => e.localName == 'activity')) {
      final name = activity.getAttribute('android:name');
      if (name == null || name.trim().isEmpty) continue;

      if (!isAndroidLauncherActivity(activity)) continue;

      final trimmed = name.trim();
      if (!trimmed.startsWith('.') && trimmed.contains('.')) return trimmed;

      final base = tryDetectAndroidPackage(projectRoot);
      if (base == null) return null;
      return trimmed.startsWith('.') ? '$base$trimmed' : '$base.$trimmed';
    }
  }

  return null;
}

/// Attempts to detect the Android module namespace of `android/app`.
///
/// The namespace is what `R` is generated under, which is a different concept
/// from the application id: build variants can carry a different
/// `applicationId` while `R` stays in the one namespace the module declares.
///
/// Reads `namespace` from `android/app/build.gradle(.kts)` and falls back to
/// the AndroidManifest `package` attribute, which is the pre-AGP-7 spelling of
/// the same thing. Returns `null` if neither is present.
String? tryDetectAndroidNamespace(Directory projectRoot) {
  // 1) android/app/build.gradle(.kts) namespace "..."
  final gradleGroovy = File(
    p.join(projectRoot.path, 'android', 'app', 'build.gradle'),
  );
  final gradleKts = File(
    p.join(projectRoot.path, 'android', 'app', 'build.gradle.kts'),
  );
  final namespace = _tryReadNamespaceFromGradle(gradleGroovy) ??
      _tryReadNamespaceFromGradle(gradleKts);
  if (namespace != null) return namespace;

  // 2) (Fallback) AndroidManifest.xml package="..."
  final manifest = File(
    p.join(
      projectRoot.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  return _tryReadPackageFromManifest(manifest);
}

/// Matches both the Groovy (`x "y"`) and Kotlin DSL (`x = "y"`) spellings.
///
/// The leading guard keeps the match from starting mid-identifier, so a
/// same-suffix property (`myapplicationId`) is not read as `applicationId`.
RegExp _gradleAssignment(String property) => RegExp(
      '''(?:^|[^A-Za-z0-9_.])$property(?:\\s*=\\s*|\\s+)['"]([^'"]+)['"]''',
      multiLine: true,
    );

String? _tryReadNamespaceFromGradle(File gradleFile) {
  if (!gradleFile.existsSync()) return null;
  final text = gradleFile.readAsStringSync();
  return _gradleAssignment('namespace').firstMatch(text)?.group(1);
}

String? _tryReadApplicationIdFromGradle(File gradleFile) {
  if (!gradleFile.existsSync()) return null;
  final text = gradleFile.readAsStringSync();
  return _gradleAssignment('applicationId').firstMatch(text)?.group(1);
}

String? _tryInferPackageFromKotlinDir(Directory kotlinMainDir) {
  if (!kotlinMainDir.existsSync()) return null;
  // Look for the first "com/..." style tree with at least 2 segments.
  final entities = kotlinMainDir.listSync(followLinks: false);
  for (final e in entities) {
    if (e is Directory) {
      final maybe = _walkPackageDirs(kotlinMainDir, e, []);
      if (maybe != null) return maybe;
    }
  }
  return null;
}

String? _walkPackageDirs(
  Directory root,
  Directory current,
  List<String> segments,
) {
  final name = p.basename(current.path);
  final nextSegments = [...segments, name];

  // Heuristic: if we have 2+ segments and see at least one Kotlin file inside
  // this directory (or below), assume package is these segments joined by dots.
  final files = current
      .listSync(recursive: false, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.kt'));
  if (nextSegments.length >= 2 && files.isNotEmpty) {
    return nextSegments.join('.');
  }

  final children = current.listSync(followLinks: false).whereType<Directory>();
  for (final child in children) {
    final maybe = _walkPackageDirs(root, child, nextSegments);
    if (maybe != null) return maybe;
  }

  return null;
}
