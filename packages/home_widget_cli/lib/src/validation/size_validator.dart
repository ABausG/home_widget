import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';
import '../util/logger.dart';

/// How many sized layouts one Android widget may declare, which is what
/// `RemoteViews` rejects a seventeenth of.
const int _maxAndroidSizes = 16;

/// The `minResize` the target-span warning suggests, in dp: one launcher row.
const int _suggestedMinResize = 40;

/// Validates the [HWSizeAdaptive] instances of [spec] against the families the
/// widget can actually be shown in.
///
/// A reachable family without content is an error, because the widget would
/// render nothing there; content no family reaches is a warning, because it
/// only ever costs the developer their layout.
///
/// Once an instance carries [HWSizeAdaptive.androidSizeRanges], the Android
/// answers come off the threshold grid the widget declares instead: a slot or
/// a range is rendered exactly where some corner of it renders.
void validateSizeAdaptive(WidgetSpec spec) {
  final iosSites = spec.iosSizeAdaptiveSites;
  final androidSites = spec.androidSizeAdaptiveSites;
  if (iosSites.isEmpty && androidSites.isEmpty) return;

  final adaptives = <HWSizeAdaptive>[];
  for (final site in [...iosSites, ...androidSites]) {
    if (adaptives.any((other) => identical(other, site.adaptive))) continue;
    adaptives.add(site.adaptive);
  }

  _validateRangeBounds(spec, adaptives);
  _validateAndroidSizes(spec, adaptives);

  // Compiled once: every Android rule below asks the same grid, walked over
  // every corner the thresholds cut, merged away or not. A family is asked for
  // at all of them, while a slot is only rendered where a kept corner renders
  // it, which is what the rules needing that filter [grid.sizes] for.
  final grid = spec.androidHasSizeRanges ? spec.androidSizeGrid : null;
  final corners = grid == null ? null : _fullCorners(grid);
  final cells = grid == null ? null : _androidCells(spec, grid, corners!);

  _validateDeclaredSizes(spec, grid);
  _validateMissingContent(spec, iosSites, androidSites, grid, cells);
  _warnUnrenderedRanges(spec, adaptives, androidSites, grid, corners);
  _warnBelowTargetSpan(spec, adaptives, androidSites);
  _warnUnreachableSlots(spec, adaptives, iosSites, androidSites, grid, cells);
  _warnNonNestingFamilies(spec, grid);
  _warnSlotShapes(spec, adaptives, iosSites, androidSites);
}

/// Every corner the thresholds cut, before merging and dropping.
///
/// A corner the grid drops is still a size the widget can be shown at: some
/// kept corner answers for it, so the family it asks for still has to have
/// content, and a range matching only there was matched by an earlier one
/// rather than never reached.
List<HWSize> _fullCorners(HWAndroidSizeGrid grid) => [
      for (final height in grid.heightThresholds)
        for (final width in grid.widthThresholds) HWSize(width, height),
    ];

/// The grid corners every Android-reached [HWSizeAdaptive] answers for.
///
/// The root instance answers for all of them; a nested one only for the
/// corners where the slot or range child it sits in is what its enclosing
/// instance renders there.
class _AndroidCells {
  final List<HWSizeAdaptive> _instances;
  final List<List<HWSize>> _cells;

  const _AndroidCells(this._instances, this._cells);

  List<HWSize> of(HWSizeAdaptive adaptive) {
    final index = _instances.indexWhere((other) => identical(other, adaptive));
    return index == -1 ? const [] : _cells[index];
  }
}

_AndroidCells _androidCells(
  WidgetSpec spec,
  HWAndroidSizeGrid grid,
  List<HWSize> corners,
) {
  final instances = <HWSizeAdaptive>[];
  final cells = <List<HWSize>>[];

  void walk(HWWidget widget, List<HWSize> at) {
    switch (widget) {
      case HWAdaptive():
        walk(widget.android, at);
      case HWSizeAdaptive():
        final index = instances.indexWhere((other) => identical(other, widget));
        if (index == -1) {
          instances.add(widget);
          cells.add([...at]);
        } else {
          for (final cell in at) {
            if (!cells[index].contains(cell)) cells[index].add(cell);
          }
        }

        final walked = <HWWidget>[];
        for (final child in [
          ...widget.providedSlots,
          ...widget.androidSizeRangeChildren,
        ]) {
          if (walked.any((other) => identical(other, child))) continue;
          walked.add(child);
          walk(child, [
            for (final cell in at)
              if (identical(widget.renderAtAndroid(cell, grid.table), child))
                cell,
          ]);
        }
      default:
        for (final child in widget.childWidgets) {
          walk(child, at);
        }
    }
  }

  walk(spec.effectiveWidgetTree, corners);
  return _AndroidCells(instances, cells);
}

/// Rejects an [HWAndroidSizeRange] bound no real widget size can be compared
/// against.
void _validateRangeBounds(WidgetSpec spec, List<HWSizeAdaptive> adaptives) {
  for (final adaptive in adaptives) {
    for (final range in adaptive.androidSizeRangesOrEmpty) {
      _validateBoundAxis(spec, 'Width', range.minWidth, range.maxWidth);
      _validateBoundAxis(spec, 'Height', range.minHeight, range.maxHeight);
    }
  }
}

void _validateBoundAxis(
  WidgetSpec spec,
  String axis,
  double? min,
  double? max,
) {
  final shared = 'Widget "${spec.data.name}": an HWAndroidSizeRange has';

  if (min != null && (min < 0 || !min.isFinite)) {
    throw GeneratorError(
      '$shared min$axis ${_bound(min)}. A minimum must be a finite dp value of '
      '0 or more.',
    );
  }
  if (max != null && (max < 0 || max.isNaN)) {
    throw GeneratorError(
      '$shared max$axis ${_bound(max)}. A maximum must be a dp value of 0 or '
      'more, or double.infinity for no bound at all.',
    );
  }
  if (min != null && max != null && min > max) {
    throw GeneratorError(
      '$shared min$axis ${_bound(min)} and max$axis ${_bound(max)}. A minimum '
      'must not exceed its maximum.',
    );
  }
}

/// Rejects a grid the platform would throw the seventeenth layout of away.
void _validateDeclaredSizes(WidgetSpec spec, HWAndroidSizeGrid? grid) {
  if (grid == null || grid.sizes.length <= _maxAndroidSizes) return;

  final widths = <double>{for (final size in grid.sizes) size.width}.toList()
    ..sort();
  final heights = <double>{for (final size in grid.sizes) size.height}.toList()
    ..sort();
  final familyExtents = <double>{
    for (final size in grid.table.values) ...[size.width, size.height],
  }.toList()
    ..sort();

  throw GeneratorError(
    'Widget "${spec.data.name}" needs ${grid.sizes.length} Android sizes to '
    'place its HWAndroidSizeRange bounds exactly (widths '
    '${_dimensions(widths)}; heights ${_dimensions(heights)}). Android renders '
    'at most $_maxAndroidSizes per widget. Reuse bounds (the family sizes '
    '${_andList(familyExtents.map(HWSize.dimension).toList())} cost nothing '
    'extra) or drop a range.',
  );
}

/// Rejects `androidSizes` that no resolved size table could be built from, and
/// warns about a family that an override made smaller than its own fallback.
void _validateAndroidSizes(WidgetSpec spec, List<HWSizeAdaptive> adaptives) {
  final declared = <HWWidgetFamily, HWSize>{};
  final conflicts = <HWWidgetFamily, (HWSize, HWSize)>{};

  for (final adaptive in adaptives) {
    final sizes = adaptive.androidSizes;
    if (sizes == null) continue;

    for (final family in HWWidgetFamily.values) {
      final size = sizes[family];
      if (size == null) continue;

      if (family.isAccessory) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWSizeAdaptive.androidSizes has an '
          'entry for ${family.name}. Android has no accessory families, so '
          'only the system families can be given a size.',
        );
      }
      if (size.width <= 0 || size.height <= 0) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWSizeAdaptive.androidSizes gives '
          '${family.name} $size. A width and a height must be greater than 0.',
        );
      }

      final existing = declared[family];
      if (existing != null && existing != size) {
        conflicts[family] ??= (existing, size);
      }
      declared[family] = size;
    }
  }

  for (final entry in conflicts.entries) {
    final (first, second) = entry.value;
    throw GeneratorError(
      'Widget "${spec.data.name}": two HWSizeAdaptive instances give '
      '${entry.key.name} different androidSizes ($first and $second). sizeMode '
      'is declared once per widget, so an override applies to the whole tree '
      'and every instance has to agree.',
    );
  }

  // The resolved table only reaches a generated widget through the Android
  // sources, so it is only worth reasoning about when there are any.
  if (spec.data.android == null) return;

  final table = spec.androidSizeTable;

  final bySize = <HWSize, HWWidgetFamily>{};
  for (final family in HWWidgetFamily.values) {
    final size = table[family];
    if (size == null) continue;
    final clash = bySize[size];
    if (clash != null) {
      throw GeneratorError(
        'Widget "${spec.data.name}": ${clash.name} and ${family.name} both '
        'declare $size on Android. Glance cannot tell two identical sizes '
        'apart, so give them different androidSizes.',
      );
    }
    bySize[size] = family;
  }

  for (final family in HWWidgetFamily.values) {
    final size = table[family];
    if (size == null) continue;
    for (final fallback in family.fallbackChain) {
      final fallbackSize = table[fallback];
      if (fallbackSize == null) continue;
      if (size.width >= fallbackSize.width &&
          size.height >= fallbackSize.height) {
        continue;
      }
      logger.warn(
        'Warning: Widget "${spec.data.name}": androidSizes make '
        '${family.name} ($size) smaller than its fallback ${fallback.name} '
        '($fallbackSize). Content written for ${fallback.name} would be '
        'rendered in a smaller box.',
      );
    }
  }
}

/// Rejects an [HWSizeAdaptive] that renders nothing for a family the widget
/// can be shown in, naming every such family in one error.
void _validateMissingContent(
  WidgetSpec spec,
  List<HWSizeAdaptiveSite> iosSites,
  List<HWSizeAdaptiveSite> androidSites,
  HWAndroidSizeGrid? grid,
  _AndroidCells? cells,
) {
  Set<HWWidgetFamily> missing(List<HWSizeAdaptiveSite> sites) => {
        for (final site in sites)
          for (final family in site.visible)
            if (site.adaptive.resolve(family) == null) family,
      };

  final onIos = missing(iosSites);
  final onAndroid = grid == null
      ? missing(androidSites)
      : _missingOnGrid(spec, androidSites, grid, cells!);
  if (onIos.isEmpty && onAndroid.isEmpty) return;

  final message = StringBuffer();
  for (final family in HWWidgetFamily.values) {
    final where = <String>[
      if (onIos.contains(family)) 'iOS',
      if (onAndroid.contains(family)) 'Android',
    ];
    if (where.isEmpty) continue;
    message.writeln(
      'HWSizeAdaptive has no content for ${family.name}, which '
      '"${spec.data.name}" supports on ${_joinWithAnd(where)}. '
      '${_addSlotAdvice(family)}',
    );
  }
  throw GeneratorError(message.toString().trimRight());
}

/// The families a corner of the grid asks an instance for without getting
/// anything back.
///
/// A family is missing where all of this holds: it is one the widget can be
/// shown in at all, the instance resolves nothing for it, and some corner both
/// picks it and is a size the widget can really be resized to. The grid is
/// floored at the widget's minimum size, so every corner starts inside what it
/// can be resized to, and a range answers for the corners it matches, so
/// neither may demand content.
Set<HWWidgetFamily> _missingOnGrid(
  WidgetSpec spec,
  List<HWSizeAdaptiveSite> androidSites,
  HWAndroidSizeGrid grid,
  _AndroidCells cells,
) {
  final reachable = spec.androidReachableFamilies;
  final max = spec.androidMaxSize;

  final missing = <HWWidgetFamily>{};
  for (final site in androidSites) {
    for (final family in reachable) {
      if (site.adaptive.resolve(family) != null) continue;
      for (final corner in cells.of(site.adaptive)) {
        if (site.adaptive.androidSizeRangeAt(corner) != null) continue;
        if (HWAndroidSizeGrid.familyAt(grid.table, corner) != family) continue;
        if (!_cellInRange(corner.width, max.width)) continue;
        if (!_cellInRange(corner.height, max.height)) continue;
        missing.add(family);
        break;
      }
    }
  }
  return missing;
}

/// Whether the cell a corner opens on one axis overlaps what the widget can be
/// resized to there.
///
/// The cell runs from the corner up to the next threshold, and every corner
/// sits at or above the widget's minimum size, so only the maximum can put one
/// out of reach.
bool _cellInRange(double value, double? max) => max == null || value <= max;

/// Warns about an [HWAndroidSizeRange] no corner of the grid renders.
void _warnUnrenderedRanges(
  WidgetSpec spec,
  List<HWSizeAdaptive> adaptives,
  List<HWSizeAdaptiveSite> androidSites,
  HWAndroidSizeGrid? grid,
  List<HWSize>? corners,
) {
  if (spec.data.android == null) return;
  final min = spec.androidMinSize;

  for (final adaptive in adaptives) {
    final ranges = adaptive.androidSizeRangesOrEmpty;
    final reached =
        androidSites.any((site) => identical(site.adaptive, adaptive));

    for (var position = 0; position < ranges.length; position++) {
      final range = ranges[position];

      final String cause;
      if (!reached) {
        cause = 'Android never renders the HWSizeAdaptive it sits on';
      } else if (grid!.rendersRange(range)) {
        continue;
      } else if (corners!.any(range.matches)) {
        cause = 'an earlier range of the same HWSizeAdaptive matches every '
            'size it would';
      } else if (_belowMinimum(range, min)) {
        cause = "it lies below the widget's minimum size";
      } else {
        cause = 'it lies beyond the maximum size the Android configuration '
            'allows';
      }

      logger.warn(
        'Warning: ${_rangeName(spec, position, range)} is never '
        'rendered: $cause.',
      );
    }
  }
}

/// Warns about an [HWAndroidSizeRange] the widget's target span keeps the
/// launcher from ever reaching.
///
/// Verified on a Pixel 7: a launcher does not shrink a widget below its
/// `targetCellWidth` / `targetCellHeight` span unless `minResizeWidth` /
/// `minResizeHeight` says it may, so a range that can only match under that
/// span never renders on a real home screen.
void _warnBelowTargetSpan(
  WidgetSpec spec,
  List<HWSizeAdaptive> adaptives,
  List<HWSizeAdaptiveSite> androidSites,
) {
  final android = spec.data.android;
  if (android == null || !spec.androidHasSizeRanges) return;

  for (final adaptive in adaptives) {
    if (!androidSites.any((site) => identical(site.adaptive, adaptive))) {
      continue;
    }

    final ranges = adaptive.androidSizeRangesOrEmpty;
    for (var position = 0; position < ranges.length; position++) {
      final range = ranges[position];
      final name = _rangeName(spec, position, range);

      _warnAxisBelowTargetSpan(
        name,
        axis: 'Height',
        unit: 'row',
        cells: android.targetCellHeight,
        minResize: android.minResizeHeight,
        max: range.maxHeight,
        resizable: _resizes(android.resizeMode, horizontal: false),
      );
      _warnAxisBelowTargetSpan(
        name,
        axis: 'Width',
        unit: 'column',
        cells: android.targetCellWidth,
        minResize: android.minResizeWidth,
        max: range.maxWidth,
        resizable: _resizes(android.resizeMode, horizontal: true),
      );
    }
  }
}

/// Warns when [max] stops below the target span of one axis, which only a
/// `minResize` bound lets the launcher go under.
///
/// A non-resizable axis is left alone: it is fixed at its target span, which
/// [_warnUnrenderedRanges] already reports the range as beyond.
void _warnAxisBelowTargetSpan(
  String name, {
  required String axis,
  required String unit,
  required int? cells,
  required int? minResize,
  required double? max,
  required bool resizable,
}) {
  if (cells == null || minResize != null || max == null || !resizable) return;
  if (max >= HWSize.cellExtent(cells)) return;

  logger.warn(
    "Warning: $name only matches below the widget's $cells-$unit target span. "
    'Launchers keep the widget at targetCell$axis ${unit}s unless '
    'minResize$axis is set; add minResize$axis '
    '($_suggestedMinResize, say) to HomeWidgetAndroidConfiguration.',
  );
}

/// Whether [mode] lets the launcher resize one axis of the widget.
bool _resizes(HWAndroidResizeMode? mode, {required bool horizontal}) =>
    mode == null ||
    mode == HWAndroidResizeMode.horizontalAndVertical ||
    mode ==
        (horizontal
            ? HWAndroidResizeMode.horizontal
            : HWAndroidResizeMode.vertical);

/// Whether a maximum bound of [range] stops below the widget's minimum size on
/// that axis, which the launcher never shrinks it under.
bool _belowMinimum(
  HWAndroidSizeRange range,
  ({double width, double height}) min,
) =>
    _stopsBelow(range.maxWidth, min.width) ||
    _stopsBelow(range.maxHeight, min.height);

bool _stopsBelow(double? bound, double minimum) =>
    bound != null && HWAndroidSizeRange.upperThreshold(bound) <= minimum;

/// Warns about a slot no reachable family ever renders.
void _warnUnreachableSlots(
  WidgetSpec spec,
  List<HWSizeAdaptive> adaptives,
  List<HWSizeAdaptiveSite> iosSites,
  List<HWSizeAdaptiveSite> androidSites,
  HWAndroidSizeGrid? grid,
  _AndroidCells? cells,
) {
  final onIosPlatform = spec.data.iOS != null;
  final onAndroidPlatform = spec.data.android != null;
  final iosTopLevel = _iosCause(spec);
  final androidTopLevel = _androidCause(spec);

  for (final adaptive in adaptives) {
    final onIos = _siteFor(iosSites, adaptive);
    final onAndroid = _siteFor(androidSites, adaptive);

    for (final family in HWWidgetFamily.values) {
      final slot = adaptive.slotFor(family);
      if (slot == null) continue;

      final rendered = (onIos != null &&
              adaptive.familiesResolvingTo(slot, onIos.visible).isNotEmpty) ||
          (onAndroid != null &&
              _androidRenders(adaptive, slot, onAndroid, grid, cells));
      if (rendered) continue;

      logger.warn(
        'Warning: HWSizeAdaptive slot `${family.slotName}` in '
        '"${spec.data.name}" is never rendered: '
        '${_siteCause(onIos, 'iOS', iosTopLevel, generated: onIosPlatform)} '
        'and ${_siteCause(
          onAndroid,
          'Android',
          androidTopLevel,
          generated: onAndroidPlatform,
        )}.',
      );
    }
  }
}

/// Whether Android renders [slot]: at one of the corners [adaptive] is shown
/// at once the widget is on the grid, else for one of the families that reach
/// [site].
bool _androidRenders(
  HWSizeAdaptive adaptive,
  HWWidget slot,
  HWSizeAdaptiveSite site,
  HWAndroidSizeGrid? grid,
  _AndroidCells? cells,
) {
  if (grid == null) {
    return adaptive.familiesResolvingTo(slot, site.visible).isNotEmpty;
  }
  return cells!.of(adaptive).any(
        (cell) =>
            grid.sizes.contains(cell) &&
            identical(adaptive.renderAtAndroid(cell, grid.table), slot),
      );
}

/// Warns about two family sizes the grid can only answer along its corners.
///
/// Where two sizes both fit and neither contains the other, today's closest-fit
/// rule follows the diagonal between them while a corner grid cannot, so one
/// of the two layouts takes the whole region.
///
/// Only two families an instance wrote a slot for count: one that merely falls
/// back to a smaller slot was never given a layout of its own to lose.
void _warnNonNestingFamilies(WidgetSpec spec, HWAndroidSizeGrid? grid) {
  if (grid == null) return;

  final table = grid.table;
  final max = spec.androidMaxSize;
  bool inRange(HWSize size) =>
      (max.width == null || size.width <= max.width!) &&
      (max.height == null || size.height <= max.height!);

  final families = [
    for (final family in HWWidgetFamily.values)
      if (table[family] != null) family,
  ];

  for (var i = 0; i < families.length; i++) {
    for (var j = i + 1; j < families.length; j++) {
      final first = table[families[i]]!;
      final second = table[families[j]]!;
      if (!inRange(first) || !inRange(second)) continue;
      if ((first.width <= second.width && first.height <= second.height) ||
          (second.width <= first.width && second.height <= first.height)) {
        continue;
      }
      final differs = grid.instances.any((instance) {
        final first = instance.slotFor(families[i]);
        final second = instance.slotFor(families[j]);
        return first != null && second != null && !identical(first, second);
      });
      if (!differs) continue;

      // The grid gives every size that fits both what its shared corner
      // renders, whichever of the two that turns out to be.
      final corner = HWSize(
        first.width > second.width ? first.width : second.width,
        first.height > second.height ? first.height : second.height,
      );
      final winner = HWAndroidSizeGrid.familyAt(table, corner)!;
      final shape = table[winner]!.width < table[winner]!.height
          ? 'wider than tall'
          : 'taller than wide';

      logger.warn(
        'Warning: in "${spec.data.name}", ${families[i].slotName} '
        '(${_dpSize(first)}) and ${families[j].slotName} (${_dpSize(second)}) '
        'render different layouts. With androidSizeRanges, sizes that fit both '
        "get ${winner.slotName}'s, even when they are $shape.",
      );
    }
  }
}

/// Warns about slot content a family cannot render the way it is written.
void _warnSlotShapes(
  WidgetSpec spec,
  List<HWSizeAdaptive> adaptives,
  List<HWSizeAdaptiveSite> iosSites,
  List<HWSizeAdaptiveSite> androidSites,
) {
  for (final adaptive in adaptives) {
    final inline = adaptive.accessoryInline;
    if (inline == null || _isInlineSlot(inline)) continue;
    logger.warn(
      'Warning: Widget "${spec.data.name}": the `accessoryInline` slot of '
      'HWSizeAdaptive is a ${inline.runtimeType}. The inline accessory '
      'renders a single line, so WidgetKit drops anything that is not an '
      'HWText, an HWImage, or an HWRow of those.',
    );
  }

  final allSites = [...iosSites, ...androidSites];
  final nested = <HWSizeAdaptive>[];
  for (final site in allSites) {
    final slot = site.enclosingSlot;
    if (slot == null && site.enclosingRange == null) continue;
    if (nested.any((other) => identical(other, site.adaptive))) continue;
    nested.add(site.adaptive);

    if (slot == null) {
      logger.warn(
        'Warning: Widget "${spec.data.name}": an HWSizeAdaptive sits inside an '
        'androidSizeRange of another one, which only renders where that range '
        'matches. The inner one can never be rendered anywhere else.',
      );
      continue;
    }

    final visible = <HWWidgetFamily>{
      for (final other in allSites)
        if (identical(other.adaptive, site.adaptive)) ...other.visible,
    };
    final families = visible.isEmpty
        ? 'no family the widget is generated for'
        : _ordered(visible).map((f) => f.name).join(', ');

    logger.warn(
      'Warning: Widget "${spec.data.name}": an HWSizeAdaptive sits inside the '
      '`${slot.slotName}` slot of another one, which only renders for '
      '$families. The inner one can never see another family.',
    );
  }
}

/// Where [adaptive] sits in [sites], or null when that platform never renders
/// it at all.
HWSizeAdaptiveSite? _siteFor(
  List<HWSizeAdaptiveSite> sites,
  HWSizeAdaptive adaptive,
) {
  for (final site in sites) {
    if (identical(site.adaptive, adaptive)) return site;
  }
  return null;
}

/// Why [site] renders what it renders on [platform], where [topLevel] is the
/// reason for an instance the widget root reaches directly.
///
/// A platform the widget is not [generated] for has one reason for everything,
/// which [topLevel] already carries.
String _siteCause(
  HWSizeAdaptiveSite? site,
  String platform,
  String topLevel, {
  required bool generated,
}) {
  if (!generated) return topLevel;
  if (site == null) return 'not rendered on $platform';

  if (site.enclosingRange != null) {
    return 'on $platform its enclosing androidSizeRange only renders where its '
        'bounds match';
  }

  final slot = site.enclosingSlot;
  if (slot == null) return topLevel;

  final families = _ordered(site.visible).map((f) => f.name).join(', ');
  return 'on $platform its enclosing `${slot.slotName}` slot only renders for '
      '[$families]';
}

/// How to give [family] content of its own, naming the fallbacks that would
/// cover it too.
String _addSlotAdvice(HWWidgetFamily family) {
  final slot = '`${family.slotName}`';
  final article = _article(family.slotName);
  final fallbacks = family.fallbackChain;
  if (fallbacks.isEmpty) return 'Add $article $slot slot.';

  final names = fallbacks.map((f) => '`${f.slotName}`').join(', ');
  return 'Add $article $slot slot or one of its fallbacks ($names).';
}

String _iosCause(WidgetSpec spec) {
  if (spec.data.iOS == null) return 'not generated for iOS';
  final families =
      _ordered(spec.iosReachableFamilies).map((f) => f.name).join(', ');
  return 'iOS supports [$families]';
}

String _androidCause(WidgetSpec spec) {
  if (spec.data.android == null) return 'not generated for Android';

  final max = spec.androidMaxSize;
  if (max.width != null && max.height != null) {
    return 'the Android configuration caps the widget at '
        '${HWSize.dimension(max.width!)} × ${HWSize.dimension(max.height!)} dp';
  }

  final min = spec.androidMinSize;
  return 'the Android configuration keeps the widget at '
      '${HWSize.dimension(min.width)} × ${HWSize.dimension(min.height)} dp or '
      'larger';
}

/// [families] in enum order, so a message reads the same on every run.
List<HWWidgetFamily> _ordered(Iterable<HWWidgetFamily> families) => [
      for (final family in HWWidgetFamily.values)
        if (families.contains(family)) family,
    ];

/// Whether [slot] is something the inline accessory can render.
bool _isInlineSlot(HWWidget slot) {
  if (_isInlineContent(slot)) return true;
  if (slot is HWRow) return slot.childWidgets.every(_isInlineContent);
  return false;
}

bool _isInlineContent(HWWidget widget) => widget is HWText || widget is HWImage;

/// A bound as it was written, which [HWSize.dimension] cannot round for the
/// infinities and the NaN the sanity rule rejects.
String _bound(double value) =>
    value.isFinite ? HWSize.dimension(value) : '$value';

/// How a warning names the range at [position] of its list.
String _rangeName(WidgetSpec spec, int position, HWAndroidSizeRange range) =>
    'the ${_ordinal(position + 1)} HWAndroidSizeRange '
    '(${_bounds(range)}) in "${spec.data.name}"';

/// The bounds of [range], the way its constructor spells them.
String _bounds(HWAndroidSizeRange range) => [
      if (range.minWidth != null) 'minWidth: ${_bound(range.minWidth!)}',
      if (range.maxWidth != null) 'maxWidth: ${_bound(range.maxWidth!)}',
      if (range.minHeight != null) 'minHeight: ${_bound(range.minHeight!)}',
      if (range.maxHeight != null) 'maxHeight: ${_bound(range.maxHeight!)}',
    ].join(', ');

String _dpSize(HWSize size) =>
    '${HWSize.dimension(size.width)} × ${HWSize.dimension(size.height)} dp';

String _dimensions(List<double> values) =>
    values.map(HWSize.dimension).join(', ');

const List<String> _ordinals = [
  'first',
  'second',
  'third',
  'fourth',
  'fifth',
  'sixth',
];

/// [position] as the word a message names a range by.
String _ordinal(int position) =>
    position <= _ordinals.length ? _ordinals[position - 1] : '${position}th';

const _vowels = {'a', 'e', 'i', 'o', 'u'};

String _article(String word) =>
    _vowels.contains(word[0].toLowerCase()) ? 'an' : 'a';

String _joinWithAnd(List<String> values) =>
    values.length == 1 ? values.single : values.join(' and ');

/// [values] as an English list: `40, 110 and 250`.
String _andList(List<String> values) {
  final head = values.take(values.length - 1).join(', ');
  return head.isEmpty ? values.last : '$head and ${values.last}';
}
