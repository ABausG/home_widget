part of 'hw_widget.dart';

/// What one [HWSizeAdaptive] instance renders at one declared size.
///
/// Codegen-internal; see [HWAndroidSizeGrid].
class HWAndroidSizeRender {
  /// The range that matched, or null when the family slots decided.
  final HWAndroidSizeRange? range;

  /// The family Glance picks here, or null when a range matched or the family
  /// table is empty.
  final HWWidgetFamily? family;

  /// What renders, or null when the instance has no content at all.
  final HWWidget? widget;

  const HWAndroidSizeRender({this.range, this.family, this.widget});
}

/// One declared size and what every instance of the grid renders there.
///
/// The size is the lower-left corner of the grid cell it stands for, which is
/// what Glance composes the layout at.
///
/// Codegen-internal; see [HWAndroidSizeGrid].
class HWAndroidSizeCell {
  /// The declared size.
  final HWSize size;

  /// What each instance renders here, in the grid's instance order.
  final List<HWAndroidSizeRender> renders;

  const HWAndroidSizeCell(this.size, this.renders);
}

/// The Android sizes an [HWSizeAdaptive] tree declares to Glance, compiled from
/// the family sizes and the [HWSizeAdaptive.androidSizeRanges] bounds.
///
/// Glance never tells a composition the widget's real size: it composes the
/// body once per declared size and lets the launcher pick one. Both the
/// platform's closest-fit rule ([pickClosest]) and the largest-area rule
/// ([pickLargest]) land on the lower-left corner of the cell a real size falls
/// into, so declaring every corner of the grid the bounds span turns each bound
/// into an exact boundary, up to Glance's own 1 dp of slack.
///
/// Corners that render what a corner below and to the left of them already
/// renders are dropped, unless [keepFamilyCompositionSize] asks for a family
/// slot never to be composed smaller than it is without ranges.
///
/// Codegen-internal, class and members alike: consumed by `home_widget_cli`,
/// not by app code. Not marked `@internal` because that package is a separate
/// one and would then fail its own analyze.
class HWAndroidSizeGrid {
  /// The instances the grid answers for, in the order they were given.
  final List<HWSizeAdaptive> instances;

  /// The resolved family table the instances are measured against.
  final Map<HWWidgetFamily, HWSize> table;

  /// Every width boundary the family sizes and the range bounds put on the
  /// axis, ascending, before merging and dropping.
  ///
  /// [sizes] only keeps the corners a layout needs; these are the boundaries
  /// the cells themselves are cut along, which is what a caller reasoning
  /// about where a family is asked for compares against.
  final List<double> widthThresholds;

  /// Every height boundary, ascending, before merging and dropping.
  final List<double> heightThresholds;

  /// The declared sizes and what they render, in (height, width) ascending
  /// order.
  final List<HWAndroidSizeCell> cells;

  const HWAndroidSizeGrid._(
    this.instances,
    this.table,
    this.widthThresholds,
    this.heightThresholds,
    this.cells,
  );

  /// Compiles the grid [instances] declare, floored at the widget's smallest
  /// size ([minWidth] × [minHeight]) and clipped to [maxWidth] and [maxHeight]
  /// where it cannot be resized further.
  ///
  /// [keepFamilyCompositionSize] keeps every corner a family slot would
  /// otherwise be composed smaller at, which only matters while something reads
  /// the composed size: custom-font text measures its room against it.
  factory HWAndroidSizeGrid.compile({
    required List<HWSizeAdaptive> instances,
    required Map<HWWidgetFamily, HWSize> table,
    required double minWidth,
    required double minHeight,
    required bool keepFamilyCompositionSize,
    double? maxWidth,
    double? maxHeight,
  }) {
    final widths = _axisThresholds(
      floor: minWidth,
      family: table.values.map((size) => size.width),
      bounds: instances.expand(
        (instance) => instance.androidSizeRangesOrEmpty
            .expand((range) => range.widthThresholds),
      ),
      max: maxWidth,
    );
    final heights = _axisThresholds(
      floor: minHeight,
      family: table.values.map((size) => size.height),
      bounds: instances.expand(
        (instance) => instance.androidSizeRangesOrEmpty
            .expand((range) => range.heightThresholds),
      ),
      max: maxHeight,
    );

    // Kept as they were cut: `_merge` thins the working lists in place.
    final fullWidths = List<double>.unmodifiable(widths);
    final fullHeights = List<double>.unmodifiable(heights);

    _merge(
      instances,
      table,
      widths,
      heights,
      keepFamilyCompositionSize: keepFamilyCompositionSize,
    );
    final kept = _drop(
      instances,
      table,
      widths,
      heights,
      keepFamilyCompositionSize: keepFamilyCompositionSize,
    );

    return HWAndroidSizeGrid._(instances, table, fullWidths, fullHeights, [
      for (final corner in kept)
        HWAndroidSizeCell(corner, _rendersAt(instances, table, corner)),
    ]);
  }

  /// The declared sizes, in (height, width) ascending order.
  List<HWSize> get sizes => [for (final cell in cells) cell.size];

  /// Every render of every cell.
  Iterable<HWAndroidSizeRender> get renders =>
      cells.expand((cell) => cell.renders);

  /// Whether any cell renders [range].
  bool rendersRange(HWAndroidSizeRange range) =>
      renders.any((render) => identical(render.range, range));

  /// Whether any cell renders [widget], which is what tells a slot nothing
  /// reaches from one the grid shows.
  bool rendersWidget(HWWidget widget) =>
      renders.any((render) => identical(render.widget, widget));

  /// Whether [declared] counts as fitting the real size [real], with the
  /// roughly 1 dp of slack `RemoteViews.fitsIn` allows.
  static bool fits(HWSize declared, HWSize real) =>
      real.width.ceilToDouble() + 1 > declared.width &&
      real.height.ceilToDouble() + 1 > declared.height;

  /// [sizes] in Glance's own `sortedBySize` order: by area, then by width.
  static List<HWSize> sortedBySize(Iterable<HWSize> sizes) =>
      [...sizes]..sort((a, b) {
          final byArea = (a.width * a.height).compareTo(b.width * b.height);
          return byArea != 0 ? byArea : a.width.compareTo(b.width);
        });

  /// The size the platform picks for the real size [real]: the fitting one
  /// closest to it, else the smallest of them all.
  static HWSize pickClosest(Iterable<HWSize> sizes, HWSize real) {
    final ordered = sortedBySize(sizes);
    HWSize? best;
    double? bestDistance;
    for (final size in ordered) {
      if (!fits(size, real)) continue;
      final dx = size.width - real.width;
      final dy = size.height - real.height;
      final distance = dx * dx + dy * dy;
      if (bestDistance == null || distance < bestDistance) {
        best = size;
        bestDistance = distance;
      }
    }
    return best ?? ordered.first;
  }

  /// What the `RemoteViews` javadoc describes instead: the fitting size with
  /// the largest area, else the smallest of them all.
  static HWSize pickLargest(Iterable<HWSize> sizes, HWSize real) {
    final ordered = sortedBySize(sizes);
    HWSize? best;
    for (final size in ordered) {
      if (!fits(size, real)) continue;
      if (best == null || size.width * size.height > best.width * best.height) {
        best = size;
      }
    }
    return best ?? ordered.first;
  }

  /// The family Glance picks at [real] among [table], or null when the table is
  /// empty.
  static HWWidgetFamily? familyAt(
    Map<HWWidgetFamily, HWSize> table,
    HWSize real,
  ) {
    if (table.isEmpty) return null;
    final picked = pickClosest(table.values, real);
    return table.entries.firstWhere((entry) => entry.value == picked).key;
  }

  /// The size a family slot is composed at without ranges, or null when no
  /// family fits [real] and Glance falls back to the smallest declared size.
  static HWSize? fittingFamilySize(
    Map<HWWidgetFamily, HWSize> table,
    HWSize real,
  ) {
    if (!table.values.any((size) => fits(size, real))) return null;
    return pickClosest(table.values, real);
  }

  /// The thresholds of one axis: the [floor], the family extents and the range
  /// bounds, dropping everything below the floor or beyond [max].
  static List<double> _axisThresholds({
    required double floor,
    required Iterable<double> family,
    required Iterable<double> bounds,
    required double? max,
  }) {
    final values = <double>{floor};
    for (final value in [...family, ...bounds]) {
      if (value < floor || !value.isFinite) continue;
      if (max != null && value > max) continue;
      values.add(value);
    }
    return values.toList()..sort();
  }

  /// Drops every threshold that renders what the one below it renders, as long
  /// as no family slot that is read at its composed size would then shrink.
  static void _merge(
    List<HWSizeAdaptive> instances,
    Map<HWWidgetFamily, HWSize> table,
    List<double> widths,
    List<double> heights, {
    required bool keepFamilyCompositionSize,
  }) {
    var changed = true;
    while (changed) {
      changed = false;
      for (var axis = 0; axis < 2 && !changed; axis++) {
        final horizontal = axis == 0;
        final thresholds = horizontal ? widths : heights;
        final others = horizontal ? heights : widths;
        for (var i = thresholds.length - 1; i > 0; i--) {
          final low = thresholds[i - 1];
          final high = thresholds[i];
          var merges = true;
          for (final other in others) {
            final upper =
                horizontal ? HWSize(high, other) : HWSize(other, high);
            final lower = horizontal ? HWSize(low, other) : HWSize(other, low);
            if (!_sameContent(instances, table, upper, lower)) {
              merges = false;
              break;
            }
            if (keepFamilyCompositionSize &&
                !_needsFamilySize(instances, table, upper, low, horizontal)) {
              merges = false;
              break;
            }
          }
          if (merges) {
            thresholds.removeAt(i);
            changed = true;
            break;
          }
        }
      }
    }
  }

  /// Whether merging [corner] down to [low] along the axis keeps a family slot
  /// composed at least as large as it is without ranges.
  static bool _needsFamilySize(
    List<HWSizeAdaptive> instances,
    Map<HWWidgetFamily, HWSize> table,
    HWSize corner,
    double low,
    bool horizontal,
  ) {
    if (!_showsFamily(instances, corner)) return true;
    final point = fittingFamilySize(table, corner);
    if (point == null) return true;
    return (horizontal ? point.width : point.height) <= low;
  }

  /// The one pass that drops the corners nothing needs, bottom row first and
  /// left to right, keeping the floor corner.
  static List<HWSize> _drop(
    List<HWSizeAdaptive> instances,
    Map<HWWidgetFamily, HWSize> table,
    List<double> widths,
    List<double> heights, {
    required bool keepFamilyCompositionSize,
  }) {
    final kept = [
      for (final height in heights)
        for (final width in widths) HWSize(width, height),
    ];
    for (final height in heights) {
      for (final width in widths) {
        final corner = HWSize(width, height);
        if (width == widths.first && height == heights.first) continue;

        // The maximal kept corners below and to the left are the ones Glance
        // could pick for this cell instead.
        final front = _front(kept, corner);
        if (front.isEmpty) continue;
        if (front.any(
          (candidate) => !_sameContent(instances, table, candidate, corner),
        )) {
          continue;
        }
        if (keepFamilyCompositionSize && _showsFamily(instances, corner)) {
          final point = fittingFamilySize(table, corner);
          if (point != null &&
              front.any(
                (candidate) =>
                    candidate.width < point.width ||
                    candidate.height < point.height,
              )) {
            continue;
          }
        }
        kept.remove(corner);
      }
    }
    return kept;
  }

  /// The maximal corners of [kept] at or below [corner] on both axes.
  static List<HWSize> _front(List<HWSize> kept, HWSize corner) {
    final below = [
      for (final candidate in kept)
        if (candidate.width <= corner.width &&
            candidate.height <= corner.height &&
            candidate != corner)
          candidate,
    ];
    return [
      for (final candidate in below)
        if (!below.any(
          (other) =>
              other != candidate &&
              other.width >= candidate.width &&
              other.height >= candidate.height,
        ))
          candidate,
    ];
  }

  /// Whether every instance renders the same at [a] as at [b].
  static bool _sameContent(
    List<HWSizeAdaptive> instances,
    Map<HWWidgetFamily, HWSize> table,
    HWSize a,
    HWSize b,
  ) {
    for (final instance in instances) {
      if (!identical(
        instance.renderAtAndroid(a, table),
        instance.renderAtAndroid(b, table),
      )) {
        return false;
      }
    }
    return true;
  }

  /// Whether a family slot decides for any instance at [size], which is what
  /// makes the composed size matter there.
  static bool _showsFamily(List<HWSizeAdaptive> instances, HWSize size) =>
      instances.any((instance) => instance.androidSizeRangeAt(size) == null);

  static List<HWAndroidSizeRender> _rendersAt(
    List<HWSizeAdaptive> instances,
    Map<HWWidgetFamily, HWSize> table,
    HWSize size,
  ) =>
      [
        for (final instance in instances)
          if (instance.androidSizeRangeAt(size) case final range?)
            HWAndroidSizeRender(range: range, widget: range.child)
          else
            HWAndroidSizeRender(
              family: familyAt(table, size),
              widget: instance.renderAtAndroid(size, table),
            ),
      ];
}
