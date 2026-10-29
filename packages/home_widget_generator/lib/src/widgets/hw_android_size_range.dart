part of 'hw_widget.dart';

/// An Android-only layout for a range of real widget sizes.
///
/// [HWSizeAdaptive.androidSizeRanges] checks its ranges before the family
/// slots, in list order, and the first one whose bounds contain the widget's
/// real size renders. Bounds are in dp, inclusive, and null is unbounded, so
/// one entry covers every one-row strip (`maxHeight: 120`) or every tablet
/// (`minWidth: 400, minHeight: 200`).
///
/// Think in dp rather than in cells: a landscape 2×2 widget is about as short
/// as a portrait one-row one, so `maxHeight` catches both.
class HWAndroidSizeRange {
  /// The smallest width in dp this range renders at, or null for no lower
  /// bound.
  final double? minWidth;

  /// The largest width in dp this range renders at, or null for no upper
  /// bound.
  final double? maxWidth;

  /// The smallest height in dp this range renders at, or null for no lower
  /// bound.
  final double? minHeight;

  /// The largest height in dp this range renders at, or null for no upper
  /// bound.
  final double? maxHeight;

  /// What renders inside the bounds.
  final HWWidget child;

  const HWAndroidSizeRange({
    required this.child,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  }) : assert(
          minWidth != null ||
              maxWidth != null ||
              minHeight != null ||
              maxHeight != null,
          boundlessMessage,
        );

  /// What a range without a single bound is rejected with.
  static const String boundlessMessage =
      'HWAndroidSizeRange needs at least one of minWidth, maxWidth, '
      'minHeight, maxHeight. A range that always matches would replace the '
      'family slots on Android; use HWAdaptive for that.';

  static HWAndroidSizeRange fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final minWidth = HWSize.dimensionOf(obj, 'minWidth');
    final maxWidth = HWSize.dimensionOf(obj, 'maxWidth');
    final minHeight = HWSize.dimensionOf(obj, 'minHeight');
    final maxHeight = HWSize.dimensionOf(obj, 'maxHeight');

    if (minWidth == null &&
        maxWidth == null &&
        minHeight == null &&
        maxHeight == null) {
      // coverage:ignore-start
      throw GeneratorError(boundlessMessage);
      // coverage:ignore-end
    }

    return HWAndroidSizeRange(
      child: decoder.decodeRecursive(WidgetValueDecoder.getField(obj, 'child')),
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
    );
  }

  /// Whether [size] falls inside the bounds.
  ///
  /// Compared in whole dp, the way Glance fits a declared size: a minimum takes
  /// effect at [lowerThreshold] and a maximum stops just below
  /// [upperThreshold], so the bounds line up with the grid the generator
  /// declares.
  bool matches(HWSize size) =>
      (minWidth == null || size.width >= lowerThreshold(minWidth!)) &&
      (maxWidth == null || size.width < upperThreshold(maxWidth!)) &&
      (minHeight == null || size.height >= lowerThreshold(minHeight!)) &&
      (maxHeight == null || size.height < upperThreshold(maxHeight!));

  /// The dp a minimum [bound] starts matching at.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code. Not
  /// marked `@internal` because that package is a separate one and would then
  /// fail its own analyze.
  static double lowerThreshold(double bound) => bound.ceilToDouble();

  /// The first dp a maximum [bound] no longer matches at.
  ///
  /// Codegen-internal; see [lowerThreshold].
  static double upperThreshold(double bound) => bound.floorToDouble() + 1;

  /// The width thresholds this range puts on the Android grid.
  ///
  /// Codegen-internal; see [lowerThreshold].
  List<double> get widthThresholds => [
        if (minWidth != null) lowerThreshold(minWidth!),
        if (maxWidth != null) upperThreshold(maxWidth!),
      ];

  /// The height thresholds this range puts on the Android grid.
  ///
  /// Codegen-internal; see [lowerThreshold].
  List<double> get heightThresholds => [
        if (minHeight != null) lowerThreshold(minHeight!),
        if (maxHeight != null) upperThreshold(maxHeight!),
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWAndroidSizeRange &&
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          minHeight == other.minHeight &&
          maxHeight == other.maxHeight &&
          child == other.child;

  @override
  int get hashCode =>
      Object.hash(minWidth, maxWidth, minHeight, maxHeight, child);

  @override
  String toString() {
    final bounds = [
      if (minWidth != null) 'minWidth: ${HWSize.dimension(minWidth!)}',
      if (maxWidth != null) 'maxWidth: ${HWSize.dimension(maxWidth!)}',
      if (minHeight != null) 'minHeight: ${HWSize.dimension(minHeight!)}',
      if (maxHeight != null) 'maxHeight: ${HWSize.dimension(maxHeight!)}',
    ];
    return 'HWAndroidSizeRange(${bounds.join(', ')})';
  }
}
