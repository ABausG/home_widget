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
/// way AGP resolves it: against the module namespace, falling back to the
/// detected application id when no namespace is declared — never against a
/// codegen package override, which names where generated files are written, not
/// where the app's classes live.
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

      final base = tryDetectAndroidNamespace(projectRoot) ??
          tryDetectAndroidPackage(projectRoot);
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

/// Attempts to detect the Gradle product flavors of `android/app`.
///
/// Scans every `*.gradle` / `*.gradle.kts` file directly under `android/app/`,
/// not only the build file: flutter_flavorizr declares the flavors in
/// `android/app/flavorizr.gradle.kts` and applies that from `build.gradle.kts`.
///
/// Text matching over the `productFlavors { … }` blocks, so it understands the
/// Kotlin (`create("dev") { … }`, `register("dev") { … }`) and Groovy
/// (`dev { … }`) spellings but no computed declaration. Returns the names in
/// declaration order, or `null` when no `productFlavors` block was found at
/// all — best effort, and only used for warnings.
List<String>? tryDetectAndroidFlavors(Directory projectRoot) {
  final appDir = Directory(p.join(projectRoot.path, 'android', 'app'));
  if (!appDir.existsSync()) return null;

  final gradleFiles = appDir
      .listSync(followLinks: false)
      .whereType<File>()
      .where(
        (f) => f.path.endsWith('.gradle') || f.path.endsWith('.gradle.kts'),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var found = false;
  final names = <String>[];
  for (final file in gradleFiles) {
    final String text;
    try {
      text = file.readAsStringSync();
    } catch (_) {
      continue;
    }
    for (final block in _productFlavorBlocks(text)) {
      found = true;
      for (final name in _flavorNamesIn(block)) {
        if (!names.contains(name)) names.add(name);
      }
    }
  }

  return found ? names : null;
}

final RegExp _productFlavorsHeader = RegExp(
  r'(?:^|[^A-Za-z0-9_.$])productFlavors\s*\{',
  multiLine: true,
);

/// The body of every `productFlavors { … }` block in [text], brace-balanced.
Iterable<String> _productFlavorBlocks(String text) sync* {
  for (final match in _productFlavorsHeader.allMatches(text)) {
    final start = match.end;
    var depth = 1;
    var i = start;
    while (i < text.length && depth > 0) {
      final char = text[i];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
      }
      i++;
    }
    if (depth == 0) yield text.substring(start, i - 1);
  }
}

final RegExp _flavorDeclaration = RegExp(
  '''(?:create|register)\\s*\\(\\s*['"]([^'"]+)['"]\\s*\\)'''
  '''|['"]([^'"]+)['"]\\s*\\{'''
  '''|(?:^|[^A-Za-z0-9_.\$])([A-Za-z_][A-Za-z0-9_]*)\\s*\\{''',
  multiLine: true,
);

/// The flavor names declared directly in a `productFlavors` block body.
Iterable<String> _flavorNamesIn(String block) => _flavorDeclaration
    .allMatches(_withoutNestedBlocks(block))
    .map((m) => m.group(1) ?? m.group(2) ?? m.group(3))
    .whereType<String>();

/// [block] with everything inside a nested `{ … }` dropped, so a property of
/// one flavor is never read as another flavor's declaration. The opening brace
/// itself is kept: it is what marks a Groovy `dev { … }` declaration.
String _withoutNestedBlocks(String block) {
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < block.length; i++) {
    final char = block[i];
    if (char == '{') {
      if (depth == 0) buffer.write(char);
      depth++;
    } else if (char == '}') {
      if (depth > 0) depth--;
      if (depth == 0) buffer.write('\n');
    } else if (depth == 0) {
      buffer.write(char);
    }
  }
  return buffer.toString();
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
