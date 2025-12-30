/// Best-effort utilities for patching Gradle build scripts.
///
/// Unlike XML, Gradle files don't have a stable, official AST we can rely on
/// here. These helpers aim to be:
/// - resilient to formatting differences (whitespace, indentation)
/// - idempotent (safe to run repeatedly)
/// - conservative (skip if we can't find expected blocks)
///
/// This is still "best-effort" text patching, but it's notably less brittle
/// than relying on exact line matches.
library;

enum GradleDialect { groovy, kts }

String ensureGlanceDependency(
  String input, {
  required GradleDialect dialect,
  required String glanceVersion,
}) {
  if (input.contains('androidx.glance:glance-appwidget')) return input;

  final lines = input.split('\n');
  final depsStart = _indexWhere(lines, RegExp(r'^\s*dependencies\s*\{'));
  final indent = depsStart == -1 ? '' : _leadingWhitespace(lines[depsStart]);
  final depLine = switch (dialect) {
    GradleDialect.groovy =>
      "${indent}    implementation 'androidx.glance:glance-appwidget:$glanceVersion'",
    GradleDialect.kts =>
      '${indent}    implementation("androidx.glance:glance-appwidget:$glanceVersion")',
  };

  if (depsStart == -1) {
    // Some newer Flutter templates don't include a `dependencies {}` block in
    // `android/app/build.gradle.kts` anymore (they rely on the Flutter Gradle
    // plugin wiring). Our patchers still need a place to insert dependencies,
    // so we append a minimal dependencies block at the end of the file.
    lines.addAll([
      '',
      'dependencies {',
      depLine.trimLeft(),
      '}',
    ]);
  } else {
    // Insert right after `dependencies {`.
    lines.insert(depsStart + 1, depLine);
  }
  return lines.join('\n');
}

String ensureComposeEnabled(
  String input, {
  required GradleDialect dialect,
  String? kotlinCompilerExtensionVersion,
}) {
  // Consider it enabled if the file already mentions compose being true.
  if (RegExp(r'\bcompose\s*(=)?\s*true\b').hasMatch(input)) return input;

  final lines = input.split('\n');
  final androidStart = _indexWhere(lines, RegExp(r'^\s*android\s*\{'));
  if (androidStart == -1) return input;

  final androidEnd = _findMatchingBlockEnd(lines, androidStart);
  if (androidEnd == null) return input;

  final baseIndent = _leadingWhitespace(lines[androidStart]);

  // 1) Ensure buildFeatures.compose is enabled.
  _ensureComposeInBuildFeatures(
    lines,
    dialect: dialect,
    androidStart: androidStart,
    androidEnd: androidEnd,
    baseIndent: baseIndent,
  );

  // 2) Ensure composeOptions.kotlinCompilerExtensionVersion is set.
  if (kotlinCompilerExtensionVersion != null) {
    _ensureComposeOptions(
      lines,
      dialect: dialect,
      androidStart: androidStart,
      androidEnd: androidEnd,
      baseIndent: baseIndent,
      kotlinCompilerExtensionVersion: kotlinCompilerExtensionVersion,
    );
  }

  return lines.join('\n');
}

void _ensureComposeInBuildFeatures(
  List<String> lines, {
  required GradleDialect dialect,
  required int androidStart,
  required int androidEnd,
  required String baseIndent,
}) {
  final buildFeaturesStart = _indexWhereInRange(
    lines,
    start: androidStart,
    endInclusive: androidEnd,
    pattern: RegExp(r'^\s*buildFeatures\s*\{'),
  );

  final composeLine = switch (dialect) {
    GradleDialect.groovy => '${baseIndent}        compose true',
    GradleDialect.kts => '${baseIndent}        compose = true',
  };

  if (buildFeaturesStart != -1) {
    final buildFeaturesEnd = _findMatchingBlockEnd(lines, buildFeaturesStart);
    if (buildFeaturesEnd == null) return;

    final already = _anyInRange(
      lines,
      start: buildFeaturesStart,
      endInclusive: buildFeaturesEnd,
      predicate: (l) => RegExp(r'\bcompose\s*(=)?\s*true\b').hasMatch(l),
    );
    if (already) return;

    // Insert right after `buildFeatures {`.
    lines.insert(buildFeaturesStart + 1, composeLine);
    return;
  }

  // Insert a new buildFeatures block near the end of android {} (before closing brace).
  final insertAt = androidEnd; // right before closing brace
  lines.insertAll(insertAt, [
    '$baseIndent    buildFeatures {',
    composeLine,
    '$baseIndent    }',
    '',
  ]);
}

void _ensureComposeOptions(
  List<String> lines, {
  required GradleDialect dialect,
  required int androidStart,
  required int androidEnd,
  required String baseIndent,
  required String kotlinCompilerExtensionVersion,
}) {
  final composeOptionsStart = _indexWhereInRange(
    lines,
    start: androidStart,
    endInclusive: androidEnd,
    pattern: RegExp(r'^\s*composeOptions\s*\{'),
  );

  final versionLine = switch (dialect) {
    GradleDialect.groovy =>
      '$baseIndent        kotlinCompilerExtensionVersion = "$kotlinCompilerExtensionVersion"',
    GradleDialect.kts =>
      '$baseIndent        kotlinCompilerExtensionVersion = "$kotlinCompilerExtensionVersion"',
  };

  if (composeOptionsStart != -1) {
    final composeOptionsEnd = _findMatchingBlockEnd(lines, composeOptionsStart);
    if (composeOptionsEnd == null) return;

    final already = _anyInRange(
      lines,
      start: composeOptionsStart,
      endInclusive: composeOptionsEnd,
      predicate: (l) => l.contains('kotlinCompilerExtensionVersion'),
    );
    if (already) return;

    lines.insert(composeOptionsStart + 1, versionLine);
    return;
  }

  // Add a new composeOptions block near the end of android {}.
  final insertAt = androidEnd; // right before closing brace
  lines.insertAll(insertAt, [
    '$baseIndent    composeOptions {',
    versionLine,
    '$baseIndent    }',
  ]);
}

String _leadingWhitespace(String line) {
  final match = RegExp(r'^\s*').firstMatch(line);
  return match?.group(0) ?? '';
}

int _indexWhere(List<String> lines, RegExp pattern) {
  for (var i = 0; i < lines.length; i++) {
    if (pattern.hasMatch(lines[i])) return i;
  }
  return -1;
}

int _indexWhereInRange(
  List<String> lines, {
  required int start,
  required int endInclusive,
  required RegExp pattern,
}) {
  final end = endInclusive.clamp(0, lines.length - 1);
  for (var i = start; i <= end; i++) {
    if (pattern.hasMatch(lines[i])) return i;
  }
  return -1;
}

bool _anyInRange(
  List<String> lines, {
  required int start,
  required int endInclusive,
  required bool Function(String line) predicate,
}) {
  final end = endInclusive.clamp(0, lines.length - 1);
  for (var i = start; i <= end; i++) {
    if (predicate(lines[i])) return true;
  }
  return false;
}

int? _findMatchingBlockEnd(List<String> lines, int startLineIdx) {
  // Start scanning at startLineIdx and count braces to find the closing brace
  // that matches the opening `... {` on the same line.
  var braceBalance = 0;
  var started = false;

  for (var i = startLineIdx; i < lines.length; i++) {
    final line = lines[i];
    for (var j = 0; j < line.length; j++) {
      final ch = line[j];
      if (ch == '{') {
        braceBalance++;
        started = true;
      } else if (ch == '}') {
        braceBalance--;
        if (started && braceBalance == 0) {
          return i; // index of the closing brace line
        }
      }
    }
  }
  return null;
}
