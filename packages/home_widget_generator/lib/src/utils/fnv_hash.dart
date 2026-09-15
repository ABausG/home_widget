/// Small, dependency-free hashing.
///
/// Generated code keys resources and measurements by content, which needs a
/// digest that is identical across runs and across packages.
library;

/// 32-bit FNV-1a hash.
int fnv1a32(String input) {
  const int fnvOffsetBasis = 0x811C9DC5;
  const int fnvPrime = 0x01000193;

  var hash = fnvOffsetBasis;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}
