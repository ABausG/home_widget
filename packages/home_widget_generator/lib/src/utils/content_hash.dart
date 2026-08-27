/// Stable content hashing for compile-time localized strings.
///
/// Constant translations live in platform resource files, which key entries by
/// name. Deriving the name from the content collapses two identical maps onto
/// one entry, and gives an edited translation a new name the generator can
/// prune the old one against.
library;

/// 32-bit FNV-1a hash.
int _fnv1a32(String input) {
  const int fnvOffsetBasis = 0x811C9DC5;
  const int fnvPrime = 0x01000193;

  var hash = fnvOffsetBasis;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

/// U+0000, spelled [String.fromCharCode] deliberately — a raw NUL byte makes
/// tools treat this file as binary. Do not change the joiner: it is part of
/// the output contract, every generated resource name depends on it.
final String _joiner = String.fromCharCode(0);

/// An 8-character hex digest of [values].
///
/// Locales are sorted first, so the digest depends on the translations rather
/// than on the order they happen to be written in.
String localizedContentHash(Map<String, String> values) {
  final entries = values.entries.map((e) => '${e.key}=${e.value}').toList()
    ..sort();
  return _fnv1a32(entries.join(_joiner)).toRadixString(16).padLeft(8, '0');
}
