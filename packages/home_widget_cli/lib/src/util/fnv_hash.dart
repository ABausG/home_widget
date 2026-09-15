/// Small, dependency-free hashing utilities.
///
/// We use this to generate stable-ish Xcode `project.pbxproj` object IDs.
///
/// Notes:
/// - Xcode object IDs are 24 hex chars (96-bit) and are typically random.
/// - For our CLI scaffolding we want determinism across runs to keep patches
///   idempotent and reviewable.
library;

import 'package:home_widget_generator/home_widget_generator_cli.dart';

export 'package:home_widget_generator/home_widget_generator_cli.dart'
    show fnv1a32;

/// Generates a 24-hex-character Xcode object ID (uppercase).
///
/// This is **not** cryptographically secure; it only needs to avoid collisions
/// within a single Xcode project with extremely high probability.
String xcodeObjectId(String seed) {
  final a = fnv1a32('A:$seed');
  final b = fnv1a32('B:$seed');
  final c = fnv1a32('C:$seed');
  return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}${c.toRadixString(16).padLeft(8, '0')}'
      .toUpperCase();
}
