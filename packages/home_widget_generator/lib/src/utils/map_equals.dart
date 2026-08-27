/// Structural equality for the small `String`-keyed maps carried by
/// annotations (translation maps, mostly).
library;

/// Compares [a] and [b] entry by entry, treating literal ordering as
/// insignificant. Two nulls are equal; a null never equals a map.
///
/// Dart maps compare by identity, so without this two annotations spelling the
/// same translations would never be equal, and localized strings would never
/// dedupe in the `Set<HWDataType>` returned by `dataDependencies`.
bool mapEquals(Map<String, String>? a, Map<String, String>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
