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

  /// The provided slots of the system families, which are the only ones
  /// Android renders.
  List<HWWidget> get _providedSystemSlots => [
        for (final family in HWWidgetFamily.values)
          if (!family.isAccessory)
            if (slotFor(family) case final slot?) slot,
      ];

  /// Whether [reachable] renders more than one distinct widget, and so needs a
  /// branch at all.
  ///
  /// Android callers pass the system families only, since the accessory slots
  /// are never emitted there.
  bool branchesFor(Set<HWWidgetFamily> reachable) =>
      !_allIdentical(_resolveAll(reachable).values);

  /// The imports [kotlinSizeMode] needs.
  static const Set<String> kotlinSizeModeImports = {
    'import androidx.glance.appwidget.SizeMode',
    'import androidx.compose.ui.unit.DpSize',
    'import androidx.compose.ui.unit.dp',
  };

  /// The `sizeMode` a Glance widget declares so that `LocalSize.current` is
  /// always one of [sizes], which are the sizes [toKotlin] compares against.
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
  )''');
    return buffer.toString();
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies =>
      providedSlots.expand((slot) => slot.dataDependencies).toSet();

  @override
  List<HWWidget> get childWidgets => providedSlots;

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// Whichever slot renders is emitted where the adaptive sits, so every one of
  /// them is laid out by the enclosing layout.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => {
        if (!_allIdentical(_providedSystemSlots)) ...{
          'import androidx.glance.LocalSize',
          'import androidx.compose.ui.unit.DpSize',
          'import androidx.compose.ui.unit.dp',
        },
        ...providedSlots
            .expand((slot) => slot.kotlinImportsIn(enclosingLinearAxis)),
      };

  /// Any slot rendering a `Text` is enough, since the slot taken is only known
  /// at runtime.
  @override
  bool get kotlinReportsBaseline =>
      providedSlots.any((slot) => slot.kotlinReportsBaseline);

  /// The text every slot Android renders lines up by, which they have to agree
  /// on: the row pads a child once, and the slot taken is only known at
  /// runtime.
  @override
  HWKotlinBaselineText? get kotlinBaselineText {
    final slots = _providedSystemSlots;
    final texts = [
      for (final slot in slots)
        if (slot.kotlinBaselineText case final text?) text,
    ];
    if (texts.isEmpty) return null;

    final first = texts.first;
    final agree = texts.length == slots.length &&
        texts.every(
          (text) =>
              text.isBitmap == first.isBitmap &&
              text.ascent(_ascentProbe) == first.ascent(_ascentProbe),
        );
    if (!agree) {
      throw GeneratorError(
        'An HWRow with HWCrossAxisAlignment.baseline cannot line up an '
        'HWSizeAdaptive whose slots render text differently. The row pads its '
        'children once, and which slot renders is only known at runtime, so '
        'either give every slot text of the same style or move the row inside '
        'the slots.',
      );
    }
    return first;
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
          group.widget
              .toSwift(indent + 1, dataExpr: dataExpr, context: context),
        );
    }

    for (final family in gated) {
      final widget = resolved[family]!;
      if (identical(widget, defaultWidget)) continue;
      buffer.writeln('''
$pad#if compiler(>=${family.swiftCompilerGate})
${pad}case .${family.name}:
${widget.toSwift(indent + 1, dataExpr: dataExpr, context: context)}
$pad#endif''');
    }

    buffer.write('''
${pad}default:
${defaultWidget.toSwift(indent + 1, dataExpr: dataExpr, context: context)}
$pad}''');
    return buffer.toString();
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final reachable = {
      for (final family in context?.reachableFamilies ?? providedFamilies)
        if (!family.isAccessory) family,
    };
    final resolved = _resolveAll(reachable);
    if (resolved.isEmpty) {
      return providedSlots.first
          .toKotlin(indent, dataExpr: dataExpr, context: context);
    }
    if (_allIdentical(resolved.values)) {
      return resolved.values.first
          .toKotlin(indent, dataExpr: dataExpr, context: context);
    }

    // A context carries the table the whole widget declares to Glance, which
    // already has every instance's overrides merged in.
    final contextTable = context?.androidSizeTable;
    final table = HWWidgetFamily.androidSizeTable(
      contextTable ?? androidSizes,
    );

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
${group.widget.toKotlin(indent + 2, dataExpr: dataExpr, context: context)}
$branchPad}''');
    }

    buffer.write('''
${branchPad}else -> {
${elseWidget.toKotlin(indent + 2, dataExpr: dataExpr, context: context)}
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
          mapEquals(androidSizes, other.androidSizes);

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

/// The data expression two slots' ascents are compared as, which only has to
/// be the same for both of them.
const String _ascentProbe = 'widgetData';

/// The families of one emitted branch and the widget they share.
class _FamilyGroup {
  final List<HWWidgetFamily> families;
  final HWWidget widget;

  _FamilyGroup(this.families, this.widget);
}
