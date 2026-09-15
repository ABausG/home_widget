import 'package:collection/collection.dart';

/// Structural equality for the small maps carried by annotations, in the shape
/// of Flutter's `mapEquals`.
///
/// Dart maps compare by identity, so without this two annotations spelling the
/// same translations would never be equal, and localized strings would never
/// dedupe in the `Set<HWDataType>` returned by `dataDependencies`.
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) =>
    const MapEquality<Object?, Object?>().equals(a, b);
