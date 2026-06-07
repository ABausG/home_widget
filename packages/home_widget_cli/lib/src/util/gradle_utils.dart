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

/// The dialect of a Gradle build script.
enum GradleDialect {
  /// Groovy-based Gradle scripts (`.gradle`).
  groovy,

  /// Kotlin Script Gradle scripts (`.gradle.kts`).
  kts,
}

/// Ensures the Kotlin Compose compiler plugin is declared in the Gradle
/// build script, inserting it idempotently if missing.
String ensureKotlinComposeCompilerPlugin(
  String input, {
  required GradleDialect dialect,
  required String kotlinVersion,
}) {
  // Idempotency.
  if (input.contains('org.jetbrains.kotlin.plugin.compose')) return input;

  final lines = input.split('\n');
  final pluginsStart = _indexWhere(lines, RegExp(r'^\s*plugins\s*\{'));
  if (pluginsStart == -1) return input;

  final pluginsEnd = _findMatchingBlockEnd(lines, pluginsStart);
  if (pluginsEnd == null) return input;

  final indent = _leadingWhitespace(lines[pluginsStart]);
  final pluginLine = switch (dialect) {
    GradleDialect.groovy =>
      "$indent    id 'org.jetbrains.kotlin.plugin.compose' version '$kotlinVersion'",
    GradleDialect.kts =>
      '$indent    id("org.jetbrains.kotlin.plugin.compose") version "$kotlinVersion"',
  };

  // Insert after the Kotlin Android plugin if present, otherwise right after
  // `plugins {`.
  var insertAt = pluginsStart + 1;
  for (var i = pluginsStart + 1; i < pluginsEnd; i++) {
    final l = lines[i];
    if (l.contains('org.jetbrains.kotlin.android') ||
        l.contains('"kotlin-android"') ||
        l.contains("id 'kotlin-android'")) {
      insertAt = i + 1;
      break;
    }
  }

  lines.insert(insertAt, pluginLine);
  return lines.join('\n');
}

/// Ensures the Jetpack Glance `appwidget` dependency is present in the
/// Gradle build script, inserting it idempotently if missing.
String ensureGlanceDependency(
  String input, {
  required GradleDialect dialect,
  required String glanceVersion,
}) {
  if (input.contains('androidx.glance:glance-appwidget')) return input;

  final lines = input.split('\n');
  final depsStart = _indexWhere(lines, RegExp(r'^\s*dependencies\s*\{'));
  // Determine indentation for the dependency line:
  // - If we have a dependencies block, try to infer the indentation used inside
  //   that block.
  // - Otherwise fall back to 4 spaces inside a newly created block.
  String depsBlockIndent = '';
  String depsItemIndent = '    ';
  if (depsStart != -1) {
    depsBlockIndent = _leadingWhitespace(lines[depsStart]);
    final depsEnd = _findMatchingBlockEnd(lines, depsStart);
    if (depsEnd != null) {
      for (var i = depsStart + 1; i < depsEnd; i++) {
        final l = lines[i];
        if (l.trim().isEmpty) continue;
        // First non-empty line within the block determines indentation.
        final leading = _leadingWhitespace(l);
        if (leading.length > depsBlockIndent.length) {
          depsItemIndent = leading;
        } else {
          depsItemIndent = '$depsBlockIndent    ';
        }
        break;
      }
      // If the block was empty, use one indent level deeper than the block.
      depsItemIndent =
          depsItemIndent.isEmpty ? '$depsBlockIndent    ' : depsItemIndent;
    } else {
      depsItemIndent = '$depsBlockIndent    ';
    }
  }

  final depLine = switch (dialect) {
    GradleDialect.groovy =>
      "${depsItemIndent}implementation 'androidx.glance:glance-appwidget:$glanceVersion'",
    GradleDialect.kts =>
      '${depsItemIndent}implementation("androidx.glance:glance-appwidget:$glanceVersion")',
  };

  if (depsStart == -1) {
    // Some newer Flutter templates don't include a `dependencies {}` block in
    // `android/app/build.gradle.kts` anymore (they rely on the Flutter Gradle
    // plugin wiring). Our patchers still need a place to insert dependencies,
    // so we append a minimal dependencies block at the end of the file.
    lines.addAll([
      '',
      'dependencies {',
      '    ${depLine.trimLeft()}',
      '}',
    ]);
  } else {
    // Insert right after `dependencies {`.
    lines.insert(depsStart + 1, depLine);
  }
  final out = lines.join('\n');
  return out.endsWith('\n') ? out : '$out\n';
}

/// Ensures Compose is enabled via `buildFeatures` (and optionally
/// `composeOptions`) in the Gradle build script.
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
    GradleDialect.groovy => '$baseIndent        compose true',
    GradleDialect.kts => '$baseIndent        compose = true',
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
