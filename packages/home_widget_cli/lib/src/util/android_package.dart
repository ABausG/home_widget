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

String? _tryReadApplicationIdFromGradle(File gradleFile) {
  if (!gradleFile.existsSync()) return null;
  final text = gradleFile.readAsStringSync();
  final match = RegExp(
    r'''applicationId\s+['"]([^'"]+)['"]''',
  ).firstMatch(text);
  return match?.group(1);
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
