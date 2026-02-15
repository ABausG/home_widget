/// Jetpack Compose Compiler ↔ Kotlin compatibility lookup.
///
/// Source: Android Developers "Jetpack Compose Kotlin Compatibility Map"
/// https://developer.android.com/jetpack/androidx/releases/compose-kotlin
///
/// This file intentionally embeds the table as a const map, so the CLI can do a
/// fast, offline lookup without relying on network access at runtime.
library;

/// Kotlin version -> *latest* compatible Compose compiler version, derived from
/// the table above (when multiple Compose compiler versions map to the same
/// Kotlin version, we pick the highest Compose compiler version).
///
/// Kotlin versions here are normalized to the `x.y.z` form as published in
/// the table (no suffixes).
const Map<String, String> kotlinToComposeCompiler = {
  '1.5.10': '1.0.0',
  '1.5.21': '1.1.0-alpha02',
  '1.5.30': '1.1.0-alpha04',
  '1.5.31': '1.1.0-beta03',
  '1.6.0': '1.1.0-rc01',
  '1.6.10': '1.2.0-alpha07',
  '1.6.20': '1.2.0-alpha08',
  '1.6.21': '1.2.0-rc02',
  '1.7.0': '1.2.0',
  '1.7.10': '1.3.1',
  '1.7.20': '1.4.0-alpha01',
  '1.7.21': '1.4.0-alpha02',
  '1.8.0': '1.4.1',
  '1.8.10': '1.4.4',
  '1.8.20': '1.4.6',
  '1.8.21': '1.4.7',
  '1.8.22': '1.4.8',
  '1.9.0': '1.5.2',
  '1.9.10': '1.5.3',
  '1.9.20': '1.5.5',
  '1.9.21': '1.5.7',
  '1.9.22': '1.5.10',
  '1.9.23': '1.5.13',
  '1.9.24': '1.5.14',
  '1.9.25': '1.5.15',
};

/// Compose compiler -> Kotlin from the table (includes prereleases too).
const Map<String, String> composeCompilerToKotlin = {
  '1.0.0': '1.5.10',
  '1.0.0-rc02': '1.5.10',
  '1.0.0-rc01': '1.5.10',
  '1.0.1': '1.5.21',
  '1.0.2': '1.5.21',
  '1.0.3': '1.5.30',
  '1.0.4': '1.5.31',
  '1.0.5': '1.5.31',
  '1.1.0': '1.6.10',
  '1.1.0-rc03': '1.6.10',
  '1.1.0-rc02': '1.6.10',
  '1.1.0-rc01': '1.6.0',
  '1.1.0-beta04': '1.6.0',
  '1.1.0-beta03': '1.5.31',
  '1.1.0-beta02': '1.5.31',
  '1.1.0-beta01': '1.5.31',
  '1.1.0-alpha06': '1.5.31',
  '1.1.0-alpha05': '1.5.31',
  '1.1.0-alpha04': '1.5.30',
  '1.1.0-alpha03': '1.5.30',
  '1.1.0-alpha02': '1.5.21',
  '1.1.0-alpha01': '1.5.21',
  '1.1.1': '1.6.10',
  '1.2.0': '1.7.0',
  '1.2.0-rc02': '1.6.21',
  '1.2.0-rc01': '1.6.21',
  '1.2.0-beta03': '1.6.21',
  '1.2.0-beta02': '1.6.21',
  '1.2.0-beta01': '1.6.21',
  '1.2.0-alpha08': '1.6.20',
  '1.2.0-alpha07': '1.6.10',
  '1.2.0-alpha06': '1.6.10',
  '1.2.0-alpha05': '1.6.10',
  '1.2.0-alpha04': '1.6.10',
  '1.2.0-alpha03': '1.6.10',
  '1.2.0-alpha02': '1.6.10',
  '1.2.0-alpha01': '1.6.10',
  '1.3.0': '1.7.10',
  '1.3.0-rc02': '1.7.10',
  '1.3.0-rc01': '1.7.10',
  '1.3.0-beta01': '1.7.10',
  '1.3.1': '1.7.10',
  '1.3.2': '1.7.20',
  '1.4.0': '1.8.0',
  '1.4.0-alpha02': '1.7.21',
  '1.4.0-alpha01': '1.7.20',
  '1.4.1': '1.8.0',
  '1.4.2': '1.8.10',
  '1.4.3': '1.8.10',
  '1.4.4': '1.8.10',
  '1.4.5': '1.8.20',
  '1.4.6': '1.8.20',
  '1.4.7': '1.8.21',
  '1.4.8': '1.8.22',
  '1.5.0': '1.9.0',
  '1.5.1': '1.9.0',
  '1.5.2': '1.9.0',
  '1.5.3': '1.9.10',
  '1.5.4': '1.9.20',
  '1.5.5': '1.9.20',
  '1.5.6': '1.9.21',
  '1.5.7': '1.9.21',
  '1.5.8': '1.9.22',
  '1.5.9': '1.9.22',
  '1.5.10': '1.9.22',
  '1.5.11': '1.9.23',
  '1.5.12': '1.9.23',
  '1.5.13': '1.9.23',
  '1.5.14': '1.9.24',
  '1.5.15': '1.9.25',
};

/// Returns the most suitable Compose compiler version for the given Kotlin
/// version, using the official compatibility table.
///
/// - If an exact match exists (by `x.y.z`), that is returned.
/// - Otherwise, for the same major/minor, the closest lower-or-equal patch is
///   returned (e.g. `1.9.26` -> `1.9.25` entry).
/// - If no compatible version can be found, returns null.
String? composeCompilerForKotlin(String kotlinVersion) {
  final normalized = _normalizeVersion3(kotlinVersion);
  if (normalized == null) return null;

  final exact = kotlinToComposeCompiler[normalized];
  if (exact != null) return exact;

  final target = _parseVersion3(normalized);
  if (target == null) return null;

  String? bestKotlin;
  for (final k in kotlinToComposeCompiler.keys) {
    final kv = _parseVersion3(k);
    if (kv == null) continue;
    if (kv.$1 != target.$1 || kv.$2 != target.$2) continue; // require same x.y
    // pick the highest kv <= target
    if (_compareVersion3(kv, target) <= 0) {
      if (bestKotlin == null) {
        bestKotlin = k;
      } else {
        final bestV = _parseVersion3(bestKotlin);
        if (bestV != null && _compareVersion3(kv, bestV) > 0) {
          bestKotlin = k;
        }
      }
    }
  }

  if (bestKotlin == null) return null;
  return kotlinToComposeCompiler[bestKotlin];
}

// --- internal helpers ---

String? _normalizeVersion3(String input) {
  // Strip whitespace and any suffix like `-RC` / `-betaXX` / `+...`.
  final trimmed = input.trim();
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(trimmed);
  if (m == null) return null;
  return '${m.group(1)}.${m.group(2)}.${m.group(3)}';
}

(int, int, int)? _parseVersion3(String v) {
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(v);
  if (m == null) return null;
  return (
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!)
  );
}

int _compareVersion3((int, int, int) a, (int, int, int) b) {
  if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
  if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
  return a.$3.compareTo(b.$3);
}
