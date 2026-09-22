part of 'hw_widget.dart';

/// A widget that renders different content per [HWWidgetFamily].
///
/// On iOS this becomes a `switch` over `widgetFamily`, on Android a `when` over
/// `LocalSize.current`. Which families are switched over comes from the
/// annotation through [HWEmitContext]; a tree emitted without one covers the
/// families it has content for.
///
/// Every slot is optional. A family without a slot of its own renders the first
/// slot along its [HWWidgetFamily.fallbackChain], so a `systemSmall`-only
/// widget is complete for every system family, while the three accessory
/// families each need a slot.
class HWSizeAdaptive extends HWWidget {
  /// Content for `systemSmall`.
  final HWWidget? small;

  /// Content for `systemMedium`.
  final HWWidget? medium;

  /// Content for `systemLarge`.
  final HWWidget? large;

  /// Content for the landscape `systemExtraLarge`.
  final HWWidget? extraLarge;

  /// Content for `systemExtraLargePortrait`.
  final HWWidget? extraLargePortrait;

  /// Content for the circular Lock Screen accessory.
  final HWWidget? accessoryCircular;

  /// Content for the rectangular Lock Screen accessory.
  final HWWidget? accessoryRectangular;

  /// Content for the inline Lock Screen accessory.
  final HWWidget? accessoryInline;

  /// Replaces the default Android dp size of the listed families.
  ///
  /// Every family left out keeps the size derived from its cell footprint. The
  /// resolved table is what the generated widget declares to Glance and what
  /// the generated `when` compares against, so an override moves both together.
  final Map<HWWidgetFamily, HWSize>? androidSizes;

  /// Android-only layouts checked before the family slots, in list order.
  ///
  /// The first range whose bounds contain the widget's real size renders;
  /// where none matches, the family slots render as they do without ranges.
  /// The generator compiles the bounds into the sizes it declares to Glance, so
  /// the launcher keeps picking the layout itself.
  ///
  /// iOS ignores them.
  final List<HWAndroidSizeRange>? androidSizeRanges;

  const HWSizeAdaptive({
    this.small,
    this.medium,
    this.large,
    this.extraLarge,
    this.extraLargePortrait,
    this.accessoryCircular,
    this.accessoryRectangular,
    this.accessoryInline,
    this.androidSizes,
    this.androidSizeRanges,
  }) : assert(
          small != null ||
              medium != null ||
              large != null ||
              extraLarge != null ||
              extraLargePortrait != null ||
              accessoryCircular != null ||
              accessoryRectangular != null ||
              accessoryInline != null,
          'HWSizeAdaptive needs at least one slot.',
        );

  static HWSizeAdaptive fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final slots = <HWWidgetFamily, HWWidget>{};
    for (final family in HWWidgetFamily.values) {
      final field = WidgetValueDecoder.getField(obj, family.slotName);
      if (field == null || field.isNull) continue;
      slots[family] = decoder.decodeRecursive(field);
    }

    if (slots.isEmpty) {
      // coverage:ignore-start
      throw GeneratorError('HWSizeAdaptive needs at least one slot.');
      // coverage:ignore-end
    }

    final androidSizes = <HWWidgetFamily, HWSize>{};
    final sizesField = WidgetValueDecoder.getField(obj, 'androidSizes');
    final sizesMap = sizesField?.toMapValue();
    if (sizesMap != null) {
      for (final entry in sizesMap.entries) {
        final family = WidgetValueDecoder.decodeEnum(
          entry.key,
          HWWidgetFamily.values,
        );
        if (family == null) {
          throw GeneratorError(
            'HWSizeAdaptive.androidSizes has a key that is not an '
            'HWWidgetFamily. Every key has to be a constant HWWidgetFamily '
            'value.',
          );
        }
        final size = HWSize.fromDartObject(entry.value);
        if (size == null) {
          throw GeneratorError(
            'HWSizeAdaptive.androidSizes gives ${family.name} a value that is '
            'not an HWSize with a width and a height.',
          );
        }
        androidSizes[family] = size;
      }
    }

    final androidSizeRanges = <HWAndroidSizeRange>[];
    final rangesField = WidgetValueDecoder.getField(obj, 'androidSizeRanges');
    final rangesList = rangesField?.toListValue();
    if (rangesList != null) {
      for (final element in rangesList) {
        if (element.isNull ||
            element.type?.element?.name != 'HWAndroidSizeRange') {
          throw GeneratorError(
            'HWSizeAdaptive.androidSizeRanges has an entry that is not an '
            'HWAndroidSizeRange: ${element.type?.element?.name}.',
          );
        }
        androidSizeRanges.add(
          HWAndroidSizeRange.fromDartObject(element, decoder),
        );
      }
    }

    return HWSizeAdaptive(
      small: slots[HWWidgetFamily.systemSmall],
      medium: slots[HWWidgetFamily.systemMedium],
      large: slots[HWWidgetFamily.systemLarge],
      extraLarge: slots[HWWidgetFamily.systemExtraLarge],
      extraLargePortrait: slots[HWWidgetFamily.systemExtraLargePortrait],
      accessoryCircular: slots[HWWidgetFamily.accessoryCircular],
      accessoryRectangular: slots[HWWidgetFamily.accessoryRectangular],
      accessoryInline: slots[HWWidgetFamily.accessoryInline],
      androidSizes: androidSizes.isEmpty ? null : androidSizes,
      androidSizeRanges: androidSizeRanges.isEmpty ? null : androidSizeRanges,
    );
  }

  /// The slot written for [family], ignoring fallbacks.
  HWWidget? slotFor(HWWidgetFamily family) => switch (family) {
        HWWidgetFamily.systemSmall => small,
        HWWidgetFamily.systemMedium => medium,
        HWWidgetFamily.systemLarge => large,
        HWWidgetFamily.systemExtraLarge => extraLarge,
        HWWidgetFamily.systemExtraLargePortrait => extraLargePortrait,
        HWWidgetFamily.accessoryCircular => accessoryCircular,
        HWWidgetFamily.accessoryRectangular => accessoryRectangular,
        HWWidgetFamily.accessoryInline => accessoryInline,
      };

  /// The content [family] renders: its own slot, else the first slot along its
  /// [HWWidgetFamily.fallbackChain], else null.
  HWWidget? resolve(HWWidgetFamily family) {
    final slot = slotFor(family);
    if (slot != null) return slot;

    for (final fallback in family.fallbackChain) {
      final candidate = slotFor(fallback);
      if (candidate != null) return candidate;
    }
    return null;
  }

  /// [androidSizeRanges], or nothing when none were written.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code. Not
  /// marked `@internal` because that package is a separate one and would then
  /// fail its own analyze.
  List<HWAndroidSizeRange> get androidSizeRangesOrEmpty =>
      androidSizeRanges ?? const [];

  /// The children of [androidSizeRanges], in list order.
  ///
  /// Codegen-internal; see [androidSizeRangesOrEmpty].
  List<HWWidget> get androidSizeRangeChildren =>
      [for (final range in androidSizeRangesOrEmpty) range.child];

  /// The first range whose bounds contain [size], or null when the family
  /// slots decide there.
  ///
  /// Codegen-internal; see [androidSizeRangesOrEmpty].
  HWAndroidSizeRange? androidSizeRangeAt(HWSize size) {
    for (final range in androidSizeRangesOrEmpty) {
      if (range.matches(size)) return range;
    }
    return null;
  }

  /// What this instance renders on Android at the real size [size], against the
  /// family sizes of [table].
  ///
  /// The first matching range wins; otherwise the family Glance picks
  /// renders, down its fallback chain, and a family without content anywhere
  /// below it leaves the first slot written, which is what the `else` branch
  /// carries today.
  ///
  /// Codegen-internal; see [androidSizeRangesOrEmpty].
  HWWidget? renderAtAndroid(HWSize size, Map<HWWidgetFamily, HWSize> table) {
    if (androidSizeRangeAt(size) case final range?) return range.child;

    final family = HWAndroidSizeGrid.familyAt(table, size);
    final widget = family == null ? null : resolve(family);
    if (widget != null) return widget;

    final slots = providedSlots;
    return slots.isEmpty ? null : slots.first;
  }

  /// The grid this instance declares on its own, which is what a tree emitted
  /// without a context compares against.
  ///
  /// An instance on its own knows no Android configuration, so the floor is
  /// 1 dp rather than the widget's minimum size, and family slots keep the size
  /// they are composed at without ranges, which is what a tree with custom-font
  /// text needs.
  List<HWSize> _androidGridSizes(Map<HWWidgetFamily, HWSize> table) =>
      HWAndroidSizeGrid.compile(
        instances: [this],
        table: table,
        minWidth: 1,
        minHeight: 1,
        keepFamilyCompositionSize: true,
      ).sizes;

  /// Which of [reachable] render [slot], so a slot nothing reaches can be
  /// reported.
  Set<HWWidgetFamily> familiesResolvingTo(
    HWWidget slot,
    Iterable<HWWidgetFamily> reachable,
  ) =>
      {
        for (final family in reachable)
          if (identical(resolve(family), slot)) family,
      };

  /// Every slot that was written, in family order.
  List<HWWidget> get providedSlots => [
        for (final family in HWWidgetFamily.values)
          if (slotFor(family) case final slot?) slot,
      ];

  /// The families that have a slot of their own.
  Set<HWWidgetFamily> get providedFamilies => {
        for (final family in HWWidgetFamily.values)
          if (slotFor(family) != null) family,
      };

  /// Whether [reachable] renders more than one distinct widget, and so needs a
  /// branch at all.
  ///
  /// Android callers pass the system families only, since the accessory slots
  /// are never emitted there.
  ///
  /// With [androidSizeRanges] the question is what the instance's own grid
  /// renders: a widget rendering one layout for every corner still needs no
  /// branch.
  bool branchesFor(Set<HWWidgetFamily> reachable) {
    if (androidSizeRangesOrEmpty.isEmpty) {
      return !_allIdentical(_resolveAll(reachable).values);
    }

    final table = HWWidgetFamily.androidSizeTable(androidSizes);
    return !_allIdentical([
      for (final size in _androidGridSizes(table))
        if (renderAtAndroid(size, table) case final widget?) widget,
    ]);
  }

  /// Whether a tree emitted without a context branches over `LocalSize.current`
  /// here: with [androidSizeRanges] the instance's own grid decides, the family
  /// slots otherwise, which is what [_kotlinChoice] does at a null context.
  bool get _branchesOnAndroid => branchesFor({
        for (final family in providedFamilies)
          if (!family.isAccessory) family,
      });

  /// The imports the `when` over `LocalSize.current` needs.
  static const Set<String> _kotlinWhenImports = {
    'import androidx.glance.LocalSize',
    'import androidx.compose.ui.unit.DpSize',
    'import androidx.compose.ui.unit.dp',
  };

  /// The imports [kotlinSizeMode] needs.
  static const Set<String> kotlinSizeModeImports = {
    'import androidx.glance.appwidget.SizeMode',
    'import androidx.compose.ui.unit.DpSize',
    'import androidx.compose.ui.unit.dp',
  };

  /// The `sizeMode` a Glance widget declares so that `LocalSize.current` is
  /// always one of [sizes], which are the sizes [toKotlin] compares against.
  ///
  /// The gallery preview declares the same set: `SizeMode.Responsive` is a
  /// `PreviewSizeMode`, so the picker picks the layout for the span it shows by
  /// the same rule the home screen does, instead of composing once at the
  /// provider's minimum size.
  static String kotlinSizeMode(Iterable<HWSize> sizes) {
    final buffer = StringBuffer()..write('''
  override val sizeMode = SizeMode.Responsive(
      setOf(
''');
    for (final size in sizes) {
      buffer.writeln('          ${size.toKotlin()},');
    }
    buffer.write('''
      )
  )
  override val previewSizeMode = sizeMode''');
    return buffer.toString();
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies =>
      childWidgets.expand((child) => child.dataDependencies).toSet();

  /// Every slot and every range child: a range renders like a slot, so it
  /// contributes data fields, fonts and icons the same way.
  @override
  List<HWWidget> get childWidgets => [
        ...providedSlots,
        ...androidSizeRangeChildren,
      ];

  @override
  String get swiftFrameAlignment => _sharedSwiftFrameAlignment(providedSlots);

  /// Whether any slot asks the frame around the adaptive to clip: cutting the
  /// others off at the room they were given is what Flutter lays them out at
  /// anyway, unless one draws past that room on purpose.
  @override
  bool get swiftClipsFrame =>
      providedSlots.any((slot) => slot.swiftClipsFrame) && !swiftDrawsPastFrame;

  /// Whether any slot draws past its frame, which keeps the one frame around
  /// the adaptive from clipping.
  @override
  bool get swiftDrawsPastFrame =>
      providedSlots.any((slot) => slot.swiftDrawsPastFrame);

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// Whichever slot renders is emitted where the adaptive sits, so every one of
  /// them is laid out by the enclosing layout.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => {
        if (_branchesOnAndroid) ..._kotlinWhenImports,
        ...childWidgets
            .expand((child) => child.kotlinImportsIn(enclosingLinearAxis)),
      };

  /// The slot taken is only known at runtime, so a stack lays out each slot
  /// Android renders by what it needs itself: the ones [toKotlin] branches
  /// over, or the one it falls back to when no system family has a slot.
  @override
  List<HWWidget> _kotlinChoices(HWEmitContext? context) {
    final slots = _kotlinRenderedSlots(context);
    return slots.isEmpty ? [providedSlots.first] : slots;
  }

  /// What the `when` over `LocalSize.current` needs, when there is one to
  /// write, which is what [_branchesOnAndroid] answers for the grid as well as
  /// for the family sizes.
  @override
  Set<String> get _kotlinChoiceImports =>
      _branchesOnAndroid ? _kotlinWhenImports : const {};

  /// The text every slot Android renders lines up by, which they have to agree
  /// on: the row pads a child once, and the slot taken is only known at
  /// runtime.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) {
    final slots = _kotlinRenderedSlots(context);
    final texts = [
      for (final slot in slots)
        if (slot.kotlinBaselineText(context) case final text?) text,
    ];
    if (texts.isEmpty) return null;

    final first = texts.first;
    final agree = texts.length == slots.length &&
        texts.every(
          (text) =>
              text.isBitmap == first.isBitmap &&
              text.readsItem == first.readsItem &&
              text.ascent(_ascentProbe) == first.ascent(_ascentProbe),
        );
    if (agree) return first;

    return HWKotlinBaselineText(
      ascent: first.ascent,
      isBitmap: texts.any((text) => text.isBitmap),
      readsItem: texts.any((text) => text.readsItem),
      kotlinImports: {
        for (final text in texts) ...text.kotlinImports,
      },
      conflict: 'An HWRow with HWCrossAxisAlignment.baseline cannot line up an '
          'HWSizeAdaptive whose slots render text differently. The row pads '
          'its children once, and which slot renders is only known at '
          'runtime, so either give every slot text of the same style or move '
          'the row inside the slots.',
    );
  }

  /// The distinct widgets Android renders, the way [toKotlin] resolves them.
  List<HWWidget> _kotlinRenderedSlots(HWEmitContext? context) {
    final resolved = _resolveAll({
      for (final family in context?.reachableFamilies ?? providedFamilies)
        if (!family.isAccessory) family,
    });
    final slots = <HWWidget>[];
    for (final widget in [...resolved.values, ...androidSizeRangeChildren]) {
      if (slots.any((slot) => identical(slot, widget))) continue;
      slots.add(widget);
    }
    return slots;
  }

  @override
  Set<String> get swiftViewModifiers => {
        if (!_allIdentical(providedSlots))
          '@Environment(\\.widgetFamily) var widgetFamily',
        ...providedSlots.expand((slot) => slot.swiftViewModifiers),
      };

  /// What each of [reachable] renders, in family order, families without
  /// content left out.
  Map<HWWidgetFamily, HWWidget> _resolveAll(Set<HWWidgetFamily> reachable) {
    final resolved = <HWWidgetFamily, HWWidget>{};
    for (final family in HWWidgetFamily.values) {
      if (!reachable.contains(family)) continue;
      final widget = resolve(family);
      if (widget != null) resolved[family] = widget;
    }
    return resolved;
  }

  /// [resolved] collapsed into one group per distinct widget, families in
  /// family order and groups ordered by their first family, leaving out the
  /// families already covered by [covered] and by [excluded].
  static List<_FamilyGroup> _groupByIdentity(
    Map<HWWidgetFamily, HWWidget> resolved,
    HWWidget covered, {
    Set<HWWidgetFamily> excluded = const {},
  }) {
    final groups = <_FamilyGroup>[];
    for (final entry in resolved.entries) {
      if (excluded.contains(entry.key)) continue;
      if (identical(entry.value, covered)) continue;

      var grouped = false;
      for (final group in groups) {
        if (identical(group.widget, entry.value)) {
          group.families.add(entry.key);
          grouped = true;
          break;
        }
      }
      if (!grouped) groups.add(_FamilyGroup([entry.key], entry.value));
    }
    return groups;
  }

  /// Whether [widgets] are all the same object, so one branch covers them.
  /// An empty or single-element run trivially is.
  static bool _allIdentical(Iterable<HWWidget> widgets) {
    if (widgets.isEmpty) return true;
    final first = widgets.first;
    return widgets.every((widget) => identical(widget, first));
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final resolved =
        _resolveAll(context?.reachableFamilies ?? providedFamilies);
    if (resolved.isEmpty) {
      return providedSlots.first
          .toSwift(indent, dataExpr: dataExpr, context: context);
    }
    if (_allIdentical(resolved.values)) {
      return resolved.values.first
          .toSwift(indent, dataExpr: dataExpr, context: context);
    }

    // The smallest reachable system family, or the first accessory one when no
    // system family is reachable.
    final defaultFamily = resolved.keys.firstWhere(
      (family) => !family.isAccessory,
      orElse: () => resolved.keys.first,
    );
    final defaultWidget = resolved[defaultFamily]!;

    final pad = '    ' * indent;
    final buffer = StringBuffer()..writeln('${pad}switch widgetFamily {');

    // A family an older toolchain has no symbol for cannot share a `case` with
    // one it knows, so each gets a case of its own behind its own gate.
    final gated = {
      for (final family in resolved.keys)
        if (family.swiftCompilerGate != null) family,
    };

    final groups = _groupByIdentity(resolved, defaultWidget, excluded: gated);
    for (final group in groups) {
      final cases =
          group.families.map((family) => '.${family.name}').join(', ');
      buffer
        ..writeln('${pad}case $cases:')
        ..writeln(
          _swiftBranch(group.widget, indent + 1, dataExpr, context),
        );
    }

    for (final family in gated) {
      final widget = resolved[family]!;
      if (identical(widget, defaultWidget)) continue;
      buffer.writeln('''
$pad#if compiler(>=${family.swiftCompilerGate})
${pad}case .${family.name}:
${_swiftBranch(widget, indent + 1, dataExpr, context)}
$pad#endif''');
    }

    buffer.write('''
${pad}default:
${_swiftBranch(defaultWidget, indent + 1, dataExpr, context)}
$pad}''');
    return buffer.toString();
  }

  /// [widget] as the body of one `case` of the `switch`, which Swift does not
  /// let be empty: a slot rendering nothing becomes an `EmptyView()`.
  static String _swiftBranch(
    HWWidget widget,
    int indent,
    String dataExpr,
    HWEmitContext? context,
  ) {
    final code = widget.toSwift(indent, dataExpr: dataExpr, context: context);
    return code.trim().isEmpty ? '${'    ' * indent}EmptyView()' : code;
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) =>
      _kotlinChoice(
        indent,
        dataExpr: dataExpr,
        context: context,
        emit: (widget, indent) =>
            widget.toKotlin(indent, dataExpr: dataExpr, context: context),
      );

  @override
  String _kotlinChoice(
    int indent, {
    required String dataExpr,
    required HWEmitContext? context,
    required String Function(HWWidget widget, int indent) emit,
  }) {
    final reachable = {
      for (final family in context?.reachableFamilies ?? providedFamilies)
        if (!family.isAccessory) family,
    };
    final resolved = _resolveAll(reachable);

    // A context carries the table the whole widget declares to Glance, which
    // already has every instance's androidSizes merged in.
    final contextTable = context?.androidSizeTable;
    final table = HWWidgetFamily.androidSizeTable(
      contextTable ?? androidSizes,
    );

    // The declared sizes are the whole widget's, so a sibling instance's
    // ranges decide them too; on its own an instance compiles its own grid.
    final declared = context?.declaredAndroidSizes ??
        (androidSizeRangesOrEmpty.isEmpty ? null : _androidGridSizes(table));
    if (declared != null && declared.isNotEmpty) {
      return _toKotlinAtSizes(
        indent,
        table: table,
        declared: declared,
        emit: emit,
      );
    }

    if (resolved.isEmpty) return emit(providedSlots.first, indent);
    if (_allIdentical(resolved.values)) {
      return emit(resolved.values.first, indent);
    }

    // Under `SizeMode.Responsive` `LocalSize.current` is one of the declared
    // sizes, so the branches compare for equality rather than for a threshold.
    final elseWidget = resolved.values.first;
    final pad = '    ' * indent;
    final branchPad = '    ' * (indent + 1);
    final buffer = StringBuffer()..writeln('${pad}when (LocalSize.current) {');

    for (final group in _groupByIdentity(resolved, elseWidget)) {
      final sizes =
          group.families.map((family) => table[family]!.toKotlin()).join(', ');
      buffer.writeln('''
$branchPad$sizes -> {
${emit(group.widget, indent + 2)}
$branchPad}''');
    }

    buffer.write('''
${branchPad}else -> {
${emit(elseWidget, indent + 2)}
$branchPad}
$pad}''');
    return buffer.toString();
  }

  /// The `when` over the sizes the whole widget declares, one branch per
  /// distinct layout.
  ///
  /// Every declared size answers through [renderAtAndroid], so a range and
  /// a family slot are grouped the same way, and the `else` carries what
  /// renders at the size Glance falls back to when nothing fits.
  ///
  /// [emit] writes each branch, so inside a stack every one of them is laid out
  /// through the stack slot the way the family `when` lays its branches out.
  String _toKotlinAtSizes(
    int indent, {
    required Map<HWWidgetFamily, HWSize> table,
    required List<HWSize> declared,
    required String Function(HWWidget widget, int indent) emit,
  }) {
    final groups = <_SizeGroup>[];
    final seen = <HWSize>{};
    for (final size in declared) {
      if (!seen.add(size)) continue;
      final widget = renderAtAndroid(size, table)!;

      var grouped = false;
      for (final group in groups) {
        if (identical(group.widget, widget)) {
          group.sizes.add(size);
          grouped = true;
          break;
        }
      }
      if (!grouped) groups.add(_SizeGroup([size], widget));
    }

    if (groups.length == 1) return emit(groups.first.widget, indent);

    final elseWidget =
        renderAtAndroid(HWAndroidSizeGrid.sortedBySize(seen).first, table)!;
    final pad = '    ' * indent;
    final branchPad = '    ' * (indent + 1);
    final buffer = StringBuffer()..writeln('${pad}when (LocalSize.current) {');

    for (final group in groups) {
      if (identical(group.widget, elseWidget)) continue;
      final sizes = group.sizes.map((size) => size.toKotlin()).join(', ');
      buffer.writeln('''
$branchPad$sizes -> {
${emit(group.widget, indent + 2)}
$branchPad}''');
    }

    buffer.write('''
${branchPad}else -> {
${emit(elseWidget, indent + 2)}
$branchPad}
$pad}''');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWSizeAdaptive &&
          small == other.small &&
          medium == other.medium &&
          large == other.large &&
          extraLarge == other.extraLarge &&
          extraLargePortrait == other.extraLargePortrait &&
          accessoryCircular == other.accessoryCircular &&
          accessoryRectangular == other.accessoryRectangular &&
          accessoryInline == other.accessoryInline &&
          mapEquals(androidSizes, other.androidSizes) &&
          listEquals(androidSizeRanges, other.androidSizeRanges);

  @override
  int get hashCode => Object.hash(
        small,
        medium,
        large,
        extraLarge,
        extraLargePortrait,
        accessoryCircular,
        accessoryRectangular,
        accessoryInline,
        _sizesHash(androidSizes),
        androidSizeRanges == null
            ? null.hashCode
            : Object.hashAll(androidSizeRanges!),
      );

  /// Order-insensitive, so two annotations spelling the same sizes in a
  /// different order agree with their `==`.
  static int _sizesHash(Map<HWWidgetFamily, HWSize>? sizes) => sizes == null
      ? null.hashCode
      : Object.hashAllUnordered([
          for (final entry in sizes.entries)
            Object.hash(entry.key, entry.value),
        ]);
}

/// The data expression an ascent is read with where only its shape matters:
/// comparing two slots' ascents.
const String _ascentProbe = 'widgetData';

/// The families of one emitted branch and the widget they share.
class _FamilyGroup {
  final List<HWWidgetFamily> families;
  final HWWidget widget;

  _FamilyGroup(this.families, this.widget);
}

/// The declared sizes of one emitted branch and the widget they share.
class _SizeGroup {
  final List<HWSize> sizes;
  final HWWidget widget;

  _SizeGroup(this.sizes, this.widget);
}
