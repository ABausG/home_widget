import 'package:home_widget_generator/home_widget_generator.dart';

import '../util/fnv_hash.dart';
import '../util/naming.dart';

/// The dp of room the Android widget root takes around the tree when
/// `android.applyContentPadding` is left on.
const double androidRootContentPadding = 16;

/// A JSON object field grouped by its root key for native codegen.
class JsonDataGroup {
  /// The root JSON key (e.g. `profile` in `profile.user.name`).
  final String key;

  /// Leaf fields under [key], each with a path and resolved type.
  final List<JsonDataField> children;

  /// Creates a [JsonDataGroup].
  const JsonDataGroup({
    required this.key,
    required this.children,
  });
}

/// A single leaf field within a [JsonDataGroup].
class JsonDataField {
  /// Path segments from the root key to the leaf (e.g. `['user', 'name']`).
  final List<String> path;

  /// Resolved data type at the leaf.
  final HWDataType<dynamic> type;

  /// Creates a [JsonDataField].
  const JsonDataField({
    required this.path,
    required this.type,
  });
}

/// An image sitting at the leaf of a [JsonDataGroup].
///
/// Its PNG is saved under a key derived from the group and the path, so the
/// same leaf always overwrites the same file.
class JsonImageField {
  /// Root key of the group this image belongs to.
  final String rootKey;

  /// Path segments from the root key down to the image.
  final List<String> path;

  /// The image declared at [path].
  final HWImageData image;

  /// Creates a [JsonImageField].
  const JsonImageField({
    required this.rootKey,
    required this.path,
    required this.image,
  });

  /// Storage key suffix for this image, relative to the widget's param prefix:
  /// `<rootKey>.<dotted.path>`.
  String get storageKey => '$rootKey.${path.join('.')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonImageField &&
          rootKey == other.rootKey &&
          storageKey == other.storageKey &&
          image == other.image;

  @override
  int get hashCode => Object.hash(rootKey, storageKey, image);
}

/// One place an [HWSizeAdaptive] sits in a widget tree, on one platform.
///
/// Nesting and [HWAdaptive] both narrow what a place can render, so the same
/// instance can be a site with one family set on iOS and another on Android.
class HWSizeAdaptiveSite {
  /// The instance found at this place.
  final HWSizeAdaptive adaptive;

  /// The families that can render here.
  final Set<HWWidgetFamily> visible;

  /// The slot of the enclosing [HWSizeAdaptive], or null at the top level and
  /// inside an [HWAndroidSizeRange], which belongs to no family.
  final HWWidgetFamily? enclosingSlot;

  /// The [HWSizeAdaptive.androidSizeRanges] entry of the enclosing instance
  /// this sits in, or null when no range encloses it.
  ///
  /// Only the Android walk ever sets it: iOS ignores the ranges.
  final HWAndroidSizeRange? enclosingRange;

  /// Creates an [HWSizeAdaptiveSite].
  const HWSizeAdaptiveSite({
    required this.adaptive,
    required this.visible,
    this.enclosingSlot,
    this.enclosingRange,
  });
}

/// One `HWColumn.builder` or `HWRow.builder` in a widget tree.
class ListDeclaration {
  /// The key of the list the builder renders its item once per entry of.
  final String key;

  /// The builder itself.
  final HWMultiChildWidget builder;

  /// The item fields the builder's item reads, as
  /// [HWMultiChildWidget.itemReads] lists them: each an [HWItemData] or an
  /// [HWTimedData] around one, re-declarations of one field included.
  final List<HWDataType<dynamic>> reads;

  /// Creates a [ListDeclaration].
  const ListDeclaration({
    required this.key,
    required this.builder,
    required this.reads,
  });

  /// The builder as a schema writes it, e.g. `HWRow.builder('forecast')`.
  String get spelling =>
      "${builder is HWColumn ? 'HWColumn' : 'HWRow'}.builder('$key')";
}

/// A list the widget stores, with every builder rendering it.
///
/// Builders sharing a key render one stored list, so an item carries every
/// field any of them reads.
class ListDataGroup {
  /// The key the list is stored and saved under, e.g. `forecast`.
  final String key;

  /// Whether the list travels inside the entries of the timed data file, its
  /// item fields read through `HWTimedData(HWItemData(...))`.
  ///
  /// A list is time-based as a whole, which `validateWidgetData` enforces, and
  /// one whose item reads no field is not time-based.
  final bool timed;

  /// The item fields, every read of one field folded into one, in the order
  /// they are first read.
  ///
  /// Each is the [HWItemData] itself, for a [timed] list too: that decides
  /// where the list is stored, not what an item holds. Reads that are not
  /// [HWDataType.isCompatibleWith] each other stay separate entries, which
  /// `validateWidgetData` rejects before any generator sees them.
  final List<HWItemData<dynamic>> fields;

  /// Every builder rendering the list, in document order.
  final List<ListDeclaration> declarations;

  /// Creates a [ListDataGroup].
  const ListDataGroup({
    required this.key,
    required this.timed,
    required this.fields,
    required this.declarations,
  });

  /// The class an item is generated as, named the same in Dart, Swift and
  /// Kotlin: `<WidgetClass><ListKey>Item`, e.g. `WeatherForecastItem`.
  String itemClassName(String widgetClassName) =>
      '$widgetClassName${toPascalCase(key)}Item';

  /// The images among [fields].
  List<HWImageData> get imageFields => [
        for (final field in fields)
          if (imageLeafOf(field) case final image?) image,
      ];

  /// The icons among [fields].
  List<HWIconData> get iconFields => [
        for (final field in fields)
          if (iconLeafOf(field) case final icon?) icon,
      ];

  /// The localized strings among [fields].
  ///
  /// An item stores one text for each, and their translations are what the
  /// widget falls back to for an item storing none.
  List<HWLocalizedString> get localizedStrings => [
        for (final field in fields)
          if (field.data case final HWLocalizedString string) string,
      ];

  /// How many sample items the widget gallery shows in place of the list.
  ///
  /// As many as the longest `previewValues` among [fields]. Without any, and
  /// provided a field sets a preview value, as many as the largest `maxItems`
  /// among [declarations], or 3 when none of them sets one. Otherwise none, and
  /// the builders render their `whenEmpty`.
  int get sampleItemCount {
    var longest = 0;
    for (final field in fields) {
      final values = field.previewValues;
      if (values != null && values.length > longest) longest = values.length;
    }
    if (longest > 0) return longest;
    if (!fields.any((field) => WidgetSpec._hasPreviewValue(field.data))) {
      return 0;
    }

    int? largest;
    for (final declaration in declarations) {
      final maxItems = declaration.builder.maxItems;
      if (maxItems != null && (largest == null || maxItems > largest)) {
        largest = maxItems;
      }
    }
    return largest ?? _defaultSampleItemCount;
  }

  /// Whether the sample items differ from each other, which only
  /// `previewValues` make them do.
  bool get variesSampleItems =>
      fields.any((field) => field.previewValues != null);

  /// The value [field], one of [fields], holds in sample item [index].
  ///
  /// Entry [index] of its `previewValues`, else its preview value, else its
  /// default value, spelled the way a `previewValues` entry is: a `String` for
  /// text, for a date's ISO 8601 text and for an image's Flutter asset path,
  /// an `int` or a `double` for a number, a `bool`, or an icon's codepoint.
  /// Past its `previewValues`, a localized field holds its
  /// `previewTranslations`, a `Map<String, String>` to resolve against the
  /// device's locales. Null leaves the field out of the item, which then
  /// renders like an item saved without it.
  Object? sampleValue(HWItemData<dynamic> field, int index) {
    final values = field.previewValues;
    if (values != null && index < values.length) return values[index];
    return switch (field.data) {
      HWLocalizedString(:final previewTranslations) => previewTranslations,
      HWDateTime(:final previewIso) => previewIso,
      HWImageData(:final previewAsset) => previewAsset,
      final data => data.previewValue ?? data.defaultValue,
    };
  }
}

/// How many sample items a list previews with when a field sets a preview
/// value, none sets `previewValues`, and no builder over it sets `maxItems`.
const int _defaultSampleItemCount = 3;

/// A runtime image among the item fields of a list.
class ListImageField {
  /// The key of the list.
  final String listKey;

  /// Whether the list is time-based.
  final bool timed;

  /// The image field.
  final HWImageData image;

  /// Creates a [ListImageField].
  const ListImageField({
    required this.listKey,
    required this.timed,
    required this.image,
  });
}

/// A Flutter asset an item image previews with in the widget gallery.
class ListPreviewAsset {
  /// The key of the list.
  final String listKey;

  /// The key of the image field.
  final String fieldKey;

  /// The entry of the field's `previewValues` naming [asset], or null when it
  /// is the field's `previewAsset`.
  final int? index;

  /// The asset key, spelled like `previewAsset`.
  final String asset;

  /// Creates a [ListPreviewAsset].
  const ListPreviewAsset({
    required this.listKey,
    required this.fieldKey,
    required this.asset,
    this.index,
  });
}

/// Whether Android draws [widget] as text into a bitmap, which the room of
/// has to be measured before it is drawn.
bool androidMeasuresText(HWWidget widget) => widget.kotlinRendersBitmapText;

/// Separator between the parts [WidgetSpec.previewContentHash] digests.
///
/// Do not change it: the digest it produces is what decides whether a launcher
/// re-renders a preview.
final String _hashSeparator = String.fromCharCode(31);

/// [seeds] resolved to their transitive closure, each helper ordered after the
/// ones it calls.
///
/// A generator can emit `helper.swift` / `helper.kotlin` down the returned list
/// and every call is already in scope. Ordering breaks ties by name, so the
/// same seeds always generate the same file.
List<HWNativeHelper> resolveNativeHelpers(Iterable<HWNativeHelper> seeds) {
  final closure = <String, HWNativeHelper>{};
  void collect(HWNativeHelper helper) {
    if (closure.containsKey(helper.name)) return;
    closure[helper.name] = helper;
    helper.dependencies.forEach(collect);
  }

  seeds.forEach(collect);

  final names = closure.keys.toList()..sort();
  final emitted = <String>{};
  final ordered = <HWNativeHelper>[];
  while (ordered.length < names.length) {
    final next = names.firstWhere(
      (name) =>
          !emitted.contains(name) &&
          closure[name]!.dependencies.every((d) => emitted.contains(d.name)),
    );
    emitted.add(next);
    ordered.add(closure[next]!);
  }
  return ordered;
}

/// Specification for a home widget.
class WidgetSpec {
  /// The annotated configuration data.
  final HomeWidget data;

  /// The name of the Dart class (from annotated class).
  final String className;

  /// The data fields exactly as the annotation declares them, one entry per
  /// place a key is mentioned.
  ///
  /// Only validation reads these; everything else wants [dataFields], where the
  /// declarations of one key have been folded together.
  final List<HWDataType<dynamic>> declaredDataFields;

  /// The widget tree definition (if any).
  final HWWidget? widgetTree;

  /// Creates a new [WidgetSpec].
  WidgetSpec({
    required this.data,
    required this.className,
    List<HWDataType<dynamic>> dataFields = const [],
    this.widgetTree,
  }) : declaredDataFields = dataFields;

  /// [declaredDataFields] with every compatible re-declaration of a key folded
  /// into a single field, in first-seen order.
  ///
  /// Declarations that are not [HWDataType.isCompatibleWith] each other stay
  /// separate entries; `validateWidgetData` rejects such a spec before any
  /// generator sees it.
  List<HWDataType<dynamic>> get dataFields {
    final merged = <HWDataType<dynamic>>[];
    for (final field in declaredDataFields) {
      final existing = merged.indexWhere((f) => f.isCompatibleWith(field));
      if (existing == -1) {
        merged.add(field);
        continue;
      }
      merged[existing] = merged[existing].mergedWith(field);
    }
    return merged;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSpec &&
          data == other.data &&
          className == other.className &&
          declaredDataFields == other.declaredDataFields &&
          widgetTree == other.widgetTree;

  @override
  int get hashCode =>
      data.hashCode ^
      className.hashCode ^
      declaredDataFields.hashCode ^
      widgetTree.hashCode;

  /// The effective widget tree, returning [widgetTree] if provided, or a
  /// generated default widget based on [dataFields].
  HWWidget get effectiveWidgetTree {
    if (widgetTree != null && widgetTree is! HWDataOnly) {
      return widgetTree!;
    }

    return HWColumn(
      children: [
        HWText.fixed(galleryName),
        for (final field in [...primitiveDataFields, ...timedDataFields])
          if (imageLeafOf(field) != null)
            HWImage(field)
          else if (iconLeafOf(field) != null)
            HWIcon.resolved(field, fontResourcePrefix: fontResourcePrefix)
          else
            HWRow(
              children: [
                HWText.fixed('${field.key}: '),
                HWText(field),
              ],
            ),
      ],
    );
  }

  /// Every place an [HWSizeAdaptive] can be rendered on iOS, in document order.
  List<HWSizeAdaptiveSite> get iosSizeAdaptiveSites =>
      _sizeAdaptiveSites(android: false, visible: iosReachableFamilies);

  /// Every place an [HWSizeAdaptive] can be rendered on Android, in document
  /// order.
  ///
  /// Android has no accessory families, so no site ever sees one.
  ///
  /// Walked once per spec: nothing a spec is built from changes afterwards, and
  /// every Android size rule asks for the same walk.
  List<HWSizeAdaptiveSite> get androidSizeAdaptiveSites =>
      _androidSizeAdaptiveSites;

  late final List<HWSizeAdaptiveSite> _androidSizeAdaptiveSites =
      List.unmodifiable(
    _sizeAdaptiveSites(android: true, visible: androidReachableFamilies),
  );

  /// Every widget Android renders, in render order.
  ///
  /// Only what the Glance emit reaches: the iOS half of an [HWAdaptive] and the
  /// slots of an [HWSizeAdaptive] no family in [androidReachableFamilies]
  /// resolves to are left out, so a widget only iOS renders is never reported.
  Iterable<HWWidget> get androidRenderedWidgets =>
      androidRenderedWithin(effectiveWidgetTree);

  /// The builders whose item draws text in a custom font, in render order.
  ///
  /// Android measures the room such a text has per widget size and per item,
  /// under a key carrying the item's index. A list of another length therefore
  /// renders keys nothing measured, so a running widget has to measure again
  /// once the number of items it shows changed.
  List<HWMultiChildWidget> get androidMeasuredItemBuilders => [
        for (final widget in androidRenderedWidgets)
          if (widget case HWMultiChildWidget(:final item?, list: _?))
            if (androidRenderedWithin(item).any(androidMeasuresText)) widget,
      ];

  /// [widget] and every widget Android renders of its subtree, in render
  /// order, left out the way [androidRenderedWidgets] leaves them out.
  Iterable<HWWidget> androidRenderedWithin(HWWidget widget) =>
      _androidRendered(widget, androidReachableFamilies);

  static Iterable<HWWidget> _androidRendered(
    HWWidget widget,
    Set<HWWidgetFamily> reachable,
  ) sync* {
    yield widget;

    if (widget is HWAdaptive) {
      yield* _androidRendered(widget.android, reachable);
      return;
    }

    if (widget is HWSizeAdaptive) {
      final seen = <HWWidget>[];
      for (final family in reachable) {
        final slot = widget.resolve(family);
        if (slot == null) continue;
        if (seen.any((other) => identical(other, slot))) continue;
        seen.add(slot);
        yield* _androidRendered(slot, reachable);
      }
      return;
    }

    for (final child in widget.childWidgets) {
      yield* _androidRendered(child, reachable);
    }
  }

  /// Every [HWSizeAdaptive] either platform reaches, in document order and
  /// without repeating an instance both trees hold.
  List<HWSizeAdaptive> get sizeAdaptives => _distinctAdaptives([
        ...iosSizeAdaptiveSites,
        ...androidSizeAdaptiveSites,
      ]);

  /// The instances of [sites], in order and without repeating one two sites
  /// share.
  static List<HWSizeAdaptive> _distinctAdaptives(
    List<HWSizeAdaptiveSite> sites,
  ) {
    final adaptives = <HWSizeAdaptive>[];
    for (final site in sites) {
      if (adaptives.any((other) => identical(other, site.adaptive))) continue;
      adaptives.add(site.adaptive);
    }
    return adaptives;
  }

  /// The [HWSizeAdaptive]s the tree reaches on one platform, each with the
  /// families that can render it.
  ///
  /// An [HWAdaptive] contributes only the branch the platform emits, and a slot
  /// of an [HWSizeAdaptive] only the families that resolve to it.
  ///
  /// The Android walk also descends into every
  /// [HWSizeAdaptive.androidSizeRanges] child, which renders like a slot there;
  /// a range belongs to no family, so a site below one keeps the families its
  /// enclosing instance can see.
  List<HWSizeAdaptiveSite> _sizeAdaptiveSites({
    required bool android,
    required Set<HWWidgetFamily> visible,
  }) {
    final sites = <HWSizeAdaptiveSite>[];

    void walk(
      HWWidget widget,
      Set<HWWidgetFamily> visible,
      HWWidgetFamily? enclosingSlot,
      HWAndroidSizeRange? enclosingRange,
    ) {
      switch (widget) {
        case HWAdaptive():
          walk(
            android ? widget.android : widget.ios,
            visible,
            enclosingSlot,
            enclosingRange,
          );
        case HWSizeAdaptive():
          sites.add(
            HWSizeAdaptiveSite(
              adaptive: widget,
              visible: visible,
              enclosingSlot: enclosingSlot,
              enclosingRange: enclosingRange,
            ),
          );
          final walked = <HWWidget>[];
          for (final family in HWWidgetFamily.values) {
            final slot = widget.slotFor(family);
            if (slot == null) continue;
            // One widget written into two slots is one place in the tree.
            if (walked.any((other) => identical(other, slot))) continue;
            walked.add(slot);
            walk(
              slot,
              Set.unmodifiable(widget.familiesResolvingTo(slot, visible)),
              family,
              null,
            );
          }
          if (!android) return;
          for (final range in widget.androidSizeRangesOrEmpty) {
            final child = range.child;
            if (walked.any((other) => identical(other, child))) continue;
            walked.add(child);
            walk(child, visible, null, range);
          }
        default:
          for (final child in widget.childWidgets) {
            walk(child, visible, enclosingSlot, enclosingRange);
          }
      }
    }

    walk(effectiveWidgetTree, visible, null, null);
    return sites;
  }

  /// The dp size declared for every system family on Android, with the
  /// [HWSizeAdaptive.androidSizes] of every instance the Android tree reaches
  /// applied.
  ///
  /// Two instances overriding one family differently is a `GeneratorError`, so
  /// by the time a generator reads this the last-wins merge is unambiguous.
  Map<HWWidgetFamily, HWSize> get androidSizeTable =>
      HWWidgetFamily.androidSizeTable({
        // Which instances the walk finds does not depend on the families
        // they can see, so the table is available before reachability is.
        for (final site in _sizeAdaptiveSites(android: true, visible: const {}))
          ...?site.adaptive.androidSizes,
      });

  /// Whether any [HWSizeAdaptive] the Android tree reaches carries
  /// [HWSizeAdaptive.androidSizeRanges], which is what puts the widget on the
  /// threshold grid instead of the family sizes.
  ///
  /// An empty list is no range at all: it renders exactly what the family
  /// slots render.
  bool get androidHasSizeRanges => _androidHasSizeRanges;

  late final bool _androidHasSizeRanges = data.android != null &&
      androidSizeAdaptiveSites
          .any((site) => site.adaptive.androidSizeRangesOrEmpty.isNotEmpty);

  /// Every [HWSizeAdaptive] the Android tree reaches, in document order and
  /// without repeating an instance the tree holds twice.
  late final List<HWSizeAdaptive> _androidGridInstances =
      List.unmodifiable(_distinctAdaptives(androidSizeAdaptiveSites));

  /// The threshold grid the Android-reached instances compile to, clipped to
  /// what the widget can be resized to.
  ///
  /// Only meaningful once [androidHasSizeRanges]: without a range the grid
  /// is the family sizes, and the widget keeps declaring those.
  HWAndroidSizeGrid get androidSizeGrid => _androidSizeGrid;

  late final HWAndroidSizeGrid _androidSizeGrid = _compileAndroidSizeGrid();

  HWAndroidSizeGrid _compileAndroidSizeGrid() {
    final configured = data.android != null;
    final min = configured ? androidMinSize : null;
    final max = configured ? androidMaxSize : null;
    return HWAndroidSizeGrid.compile(
      instances: _androidGridInstances,
      table: androidSizeTable,
      minWidth: min?.width ?? 1,
      minHeight: min?.height ?? 1,
      // Only custom-font text reads the size a layout is composed at, so
      // nothing else is worth keeping a corner for.
      keepFamilyCompositionSize: rendersAndroidBitmapText,
      maxWidth: max?.width,
      maxHeight: max?.height,
    );
  }

  /// Whether any [HWSizeAdaptive] the Android tree reaches renders more than
  /// one layout, and so needs the sizes declared to Glance.
  bool get androidBranchesOnSize {
    if (!androidHasSizeRanges) {
      return androidSizeAdaptiveSites
          .any((site) => site.adaptive.branchesFor(site.visible));
    }

    final grid = androidSizeGrid;
    for (var index = 0; index < grid.instances.length; index++) {
      final rendered = [for (final cell in grid.cells) cell.renders[index]];
      final first = rendered.first.widget;
      if (rendered.any((render) => !identical(render.widget, first))) {
        return true;
      }
    }
    return false;
  }

  /// The sizes the widget declares to Glance: the grid corners once any
  /// instance carries size ranges, else the size of every Android-reachable
  /// family, in family order.
  List<HWSize> get androidDeclaredSizes {
    if (androidHasSizeRanges) return androidSizeGrid.sizes;

    final table = androidSizeTable;
    final reachable = _androidReachableFamilies(table);
    return [
      for (final family in HWWidgetFamily.values)
        if (reachable.contains(family)) table[family]!,
    ];
  }

  /// The families the widget can be shown in on iOS.
  ///
  /// An omitted or empty `supportedFamilies` is WidgetKit's own default, which
  /// is the three home-screen system families.
  Set<HWWidgetFamily> get iosReachableFamilies {
    final iOS = data.iOS;
    if (iOS == null) return const {};

    final declared = iOS.supportedFamilies;
    if (declared == null || declared.isEmpty) {
      return const {
        HWWidgetFamily.systemSmall,
        HWWidgetFamily.systemMedium,
        HWWidgetFamily.systemLarge,
      };
    }
    return declared.toSet();
  }

  /// The smallest size the launcher can render the widget at, in dp.
  ({double width, double height}) get androidMinSize {
    final range = _androidRanges;
    return (width: range.width.min, height: range.height.min);
  }

  /// The largest size the launcher can render the widget at, in dp, with a
  /// null axis for an unbounded one.
  ({double? width, double? height}) get androidMaxSize {
    final range = _androidRanges;
    return (width: range.width.max, height: range.height.max);
  }

  /// The families the widget can be shown in on Android.
  ///
  /// Glance picks the declared size closest to what the launcher offers, so a
  /// family is only ever rendered when it fits at the widget's maximum and no
  /// family at least as large already fits at its minimum. Nothing fitting at
  /// all leaves the smallest declared size, which Glance falls back to.
  Set<HWWidgetFamily> get androidReachableFamilies =>
      _androidReachableFamilies(androidSizeTable);

  Set<HWWidgetFamily> _androidReachableFamilies(
    Map<HWWidgetFamily, HWSize> table,
  ) {
    if (data.android == null) return const {};

    final range = _androidRanges;
    final maxWidth = range.width.max;
    final maxHeight = range.height.max;

    bool fitsMax(HWSize size) =>
        (maxWidth == null || size.width <= maxWidth) &&
        (maxHeight == null || size.height <= maxHeight);
    bool fitsMin(HWSize size) =>
        size.width <= range.width.min && size.height <= range.height.min;

    final reachable = <HWWidgetFamily>{};
    for (final entry in table.entries) {
      if (!fitsMax(entry.value)) continue;
      final covered = table.entries.any(
        (other) =>
            other.key != entry.key &&
            other.value.width >= entry.value.width &&
            other.value.height >= entry.value.height &&
            fitsMin(other.value),
      );
      if (!covered) reachable.add(entry.key);
    }

    if (reachable.isNotEmpty) return reachable;
    return {_smallestDeclared(table)};
  }

  /// The family Glance falls back to when nothing fits: the one covering the
  /// least area, the earlier family in enum order winning a tie.
  static HWWidgetFamily _smallestDeclared(Map<HWWidgetFamily, HWSize> table) {
    var smallest = table.entries.first;
    for (final entry in table.entries) {
      final area = entry.value.width * entry.value.height;
      if (area < smallest.value.width * smallest.value.height) smallest = entry;
    }
    return smallest.key;
  }

  /// What the widget can be resized to on both axes, in dp.
  ({({double min, double? max}) width, ({double min, double? max}) height})
      get _androidRanges => (
            width: _androidRange(horizontal: true),
            height: _androidRange(horizontal: false)
          );

  /// What the widget can be resized to along one axis, in dp.
  ({double min, double? max}) _androidRange({required bool horizontal}) {
    final android = data.android!;
    final targetCells =
        horizontal ? android.targetCellWidth : android.targetCellHeight;
    final minimum = (horizontal ? android.minWidth : android.minHeight) ?? 80;
    final defaultExtent = targetCells != null
        ? HWSize.cellExtent(targetCells)
        : minimum.toDouble();

    final resizable = switch (android.resizeMode) {
      null || HWAndroidResizeMode.horizontalAndVertical => true,
      HWAndroidResizeMode.horizontal => horizontal,
      HWAndroidResizeMode.vertical => !horizontal,
      HWAndroidResizeMode.none => false,
    };
    if (!resizable) return (min: defaultExtent, max: defaultExtent);

    final minResize =
        horizontal ? android.minResizeWidth : android.minResizeHeight;
    final maxResize =
        horizontal ? android.maxResizeWidth : android.maxResizeHeight;
    // `minResizeWidth` defaults to `minWidth`, which the provider info always
    // carries, so a resizable widget never shrinks below it.
    return (
      min: minResize?.toDouble() ?? minimum.toDouble(),
      max: maxResize?.toDouble(),
    );
  }

  /// What the iOS emitters switch over.
  HWEmitContext get iosEmitContext =>
      HWEmitContext(reachableFamilies: iosReachableFamilies);

  /// What the Android emitters switch over, and the sizes they compare against.
  ///
  /// The declared sizes are only carried once an instance has size ranges: a
  /// family-only tree keeps branching over the family sizes it always did.
  HWEmitContext get androidEmitContext {
    final table = androidSizeTable;
    return HWEmitContext(
      reachableFamilies: _androidReachableFamilies(table),
      androidSizeTable: table,
      declaredAndroidSizes: androidHasSizeRanges ? androidDeclaredSizes : null,
    );
  }

  /// Non-JSON, non-timed [dataFields] (primitives and simple types).
  ///
  /// Includes runtime [HWImageData], whose stored value is the nullable path
  /// string that native code reads from UserDefaults / SharedPreferences.
  ///
  /// Constant localized strings are excluded: they are inlined into the widget
  /// body and must never reach the data class, preferences or `saveData`.
  /// Asset images are excluded too: native code reads them straight out of the
  /// app bundle, so they are never stored. So is an [HWItemData], which only
  /// the item of a list reads.
  List<HWDataType<dynamic>> get primitiveDataFields => dataFields
      .where((f) => f is! HWJson && f is! HWTimedData && f is! HWItemData)
      .where((f) => !(f is HWLocalizedString && f.isConstant))
      .where((f) => !(f is HWImageData && f.isAsset))
      .toList();

  /// Every localized string declared as a top-level data field, excluding
  /// time-based ones ([timedLocalizedStrings]).
  List<HWLocalizedString> get localizedStrings =>
      dataFields.whereType<HWLocalizedString>().toList();

  /// Localized strings declared as a time-based top-level data field.
  ///
  /// Held apart from [localizedStrings] because the two differ in where the
  /// stored translations come from, not in how they resolve: a time-based one
  /// is read out of the timed data file, so it must stay clear of every getter
  /// driving the read of its own preferences key.
  List<HWLocalizedString> get timedLocalizedStrings => [
        for (final field in timedDataFields)
          if (field.unwrapped case final HWLocalizedString inner) inner,
      ];

  /// Localized strings sitting at the leaf of a JSON path, which supply the
  /// fallback used when the path resolves to nothing.
  List<HWLocalizedString> get jsonLocalizedStrings => [
        for (final field in dataFields.whereType<HWJson<dynamic>>())
          if (field.leafType case final HWLocalizedString leaf) leaf,
      ];

  /// [jsonLocalizedStrings] for the time-based JSON groups, whose leaves are
  /// stored and resolved exactly like the untimed ones.
  List<HWLocalizedString> get timedJsonLocalizedStrings => [
        for (final field in timedDataFields.map((f) => f.unwrapped))
          if (field case final HWJson<dynamic> json)
            if (json.leafType case final HWLocalizedString leaf) leaf,
      ];

  /// Localized strings among the item fields of a list, which supply the
  /// fallback for an item storing no text, exactly like [jsonLocalizedStrings].
  List<HWLocalizedString> get listLocalizedStrings => [
        for (final group in listDataGroups) ...group.localizedStrings,
      ];

  /// Every localized string this widget carries, wherever it is declared.
  List<HWLocalizedString> get allLocalizedStrings => [
        ...localizedStrings,
        ...timedLocalizedStrings,
        ...jsonLocalizedStrings,
        ...timedJsonLocalizedStrings,
        ...listLocalizedStrings,
      ];

  /// Localized strings backed by a preferences key of their own, i.e.
  /// overridable one key at a time through the generated `saveData`.
  ///
  /// Time-based strings are deliberately absent: their translations arrive
  /// inside the timed data file, keyed by timestamp, so reading their own key
  /// would only ever find nothing.
  List<HWLocalizedString> get keyedLocalizedStrings =>
      localizedStrings.where((f) => !f.isConstant).toList();

  /// Localized strings fixed at build time, one entry per platform resource.
  ///
  /// Deduplicated by resource name: two identical maps in one widget describe
  /// the same resource and must not be written twice.
  List<HWLocalizedString> get constantLocalizedStrings {
    final seen = <String>{};
    return [
      for (final string in localizedStrings)
        if (string.isConstant && seen.add(string.resourceName)) string,
    ];
  }

  /// Whether the generated native code reads the OS locale list, and so needs
  /// the locale-resolution helpers.
  ///
  /// Constants and gallery strings do not: they are platform resources,
  /// resolved by the OS. Everything else the widget matches itself — while
  /// reading a stored translation map or at the render site of a JSON leaf —
  /// which is what puts the locale reader in [nativeHelpers].
  bool get needsLocaleHelpers =>
      nativeHelpers.contains(HWNativeHelper.hwCurrentLocales);

  /// Whether the generated native code reads a translation blob back out of
  /// the preferences key of a data field, which only untimed keyed fields do.
  bool get needsLocalizedRead =>
      nativeHelpers.contains(HWNativeHelper.hwReadLocalized);

  /// Whether the generated native code reads a translation map out of the
  /// timed entry that is active at render time.
  bool get needsTimedLocalizedRead =>
      nativeHelpers.contains(HWNativeHelper.hwReadTimedLocalized);

  /// Whether reading the values of the generated data class resolves a
  /// translation, and so has to be handed the OS locale list.
  ///
  /// Only Kotlin needs this: its `fromPreferences` takes the list as a
  /// parameter, while the Swift resolver reaches `Locale` on its own.
  bool get resolvesLocalizedOnRead =>
      needsLocalizedRead || needsTimedLocalizedRead;

  /// Whether the widget resolves any text itself, and so goes stale on a system
  /// language change unless it re-renders.
  bool get rendersLocalizedContent =>
      constantLocalizedStrings.isNotEmpty || needsLocaleHelpers;

  /// The flavors the widget is generated for, in declaration order.
  ///
  /// Empty when the annotation declares none, which means every flavor with the
  /// base configuration.
  List<String> get declaredFlavors =>
      data.flavors?.keys.toList() ?? const <String>[];

  /// Whether the widget restricts itself to a set of flavors.
  bool get hasFlavors => declaredFlavors.isNotEmpty;

  /// The overrides declared for [name], or null when it is not declared.
  HomeWidgetFlavor? flavor(String name) => data.flavors?[name];

  HomeWidgetFlavor? _flavor(String? name) =>
      name == null ? null : data.flavors?[name];

  /// The App Group the widget shares with the app in [flavor], where the
  /// flavor's override wins over [HomeWidgetIOSConfiguration.groupId].
  ///
  /// [flavor] null selects the base configuration. Only ever called for a
  /// widget that has an iOS configuration.
  String iosGroupIdFor(String? flavor) =>
      _flavor(flavor)?.iOS?.groupId ?? data.iOS!.groupId;

  /// The URL configured for Android, where the platform value wins over the
  /// top-level [HomeWidget.widgetUrl].
  ///
  /// A widget without an Android configuration has no Android widget generated
  /// for it, and so opens no URL there.
  String? get effectiveAndroidWidgetUrl =>
      data.android == null ? null : data.android!.widgetUrl ?? data.widgetUrl;

  /// The URL configured for iOS, where the platform value wins over the
  /// top-level [HomeWidget.widgetUrl].
  ///
  /// A widget without an iOS configuration has no iOS widget generated for it,
  /// and so opens no URL there.
  String? get effectiveIosWidgetUrl =>
      data.iOS == null ? null : data.iOS!.widgetUrl ?? data.widgetUrl;

  /// Whether a tap on the widget opens the app on Android at all.
  ///
  /// A widget that opts out is not made clickable, so a configured URL never
  /// reaches the app.
  bool get androidOpensAppOnTap => data.android?.openAppOnTap ?? true;

  /// [effectiveAndroidWidgetUrl] as the native code opens it.
  String? get androidWidgetUrl => androidOpensAppOnTap
      ? _withHomeWidgetParam(effectiveAndroidWidgetUrl)
      : null;

  /// [effectiveIosWidgetUrl] as the native code opens it.
  String? get iosWidgetUrl => _withHomeWidgetParam(effectiveIosWidgetUrl);

  /// Whether tapping the widget opens the app on Android.
  bool get hasAndroidWidgetUrl => androidWidgetUrl != null;

  /// Whether tapping the widget opens the app on iOS.
  bool get hasIosWidgetUrl => effectiveIosWidgetUrl != null;

  /// Whether tapping the widget opens the app on either platform.
  bool get hasWidgetUrl => hasAndroidWidgetUrl || hasIosWidgetUrl;

  /// Whether the Android gallery preview reads the widget's stored data, where
  /// the platform value wins over the top-level
  /// [HomeWidget.useLiveDataInPreview].
  ///
  /// True renders a field as its stored value, then its preview value, then its
  /// default; false never reaches for stored data.
  bool get androidUsesLiveDataInPreview =>
      data.android?.useLiveDataInPreview ?? data.useLiveDataInPreview;

  /// [androidUsesLiveDataInPreview] for iOS.
  bool get iosUsesLiveDataInPreview =>
      data.iOS?.useLiveDataInPreview ?? data.useLiveDataInPreview;

  /// Whether the plugin registers the generated preview with the launcher on
  /// app start, which only Android 15 and newer supports.
  bool get androidAutoUpdatePreview => data.android?.autoUpdatePreview ?? true;

  /// Whether any field ships a value the gallery preview shows in place of
  /// stored data, wherever it is declared, a list previewing sample items
  /// included.
  bool get hasPreviewValues =>
      dataLeaves.any(_hasPreviewValue) ||
      listDataGroups.any((group) => group.sampleItemCount > 0);

  /// Runtime images previewing through a Flutter asset, wherever they are
  /// declared.
  ///
  /// Validated like [assetImageFields] and read by the native generators to
  /// bundle the preview image.
  List<HWImageData> get previewAssetImageFields => [
        for (final leaf in dataLeaves)
          if (leaf case final HWImageData image)
            if (image.previewAsset != null) image,
      ];

  /// A stable hex digest of everything the generated preview renders from.
  ///
  /// The Android generator stamps it into the preview fingerprint, so that a
  /// launcher only re-renders a gallery preview once the annotation actually
  /// changed what it shows. It therefore has to cover the widget tree, every
  /// data field's shipped and preview values, and the preview configuration —
  /// and it has to be identical across runs, which rules out hashing anything
  /// backed by object identity.
  String get previewContentHash {
    final parts = <String>[
      className,
      galleryName,
      galleryDescription ?? '',
      supportedLocales.join(','),
      'live=$androidUsesLiveDataInPreview',
      'auto=$androidAutoUpdatePreview',
      // The sizes are declared on the widget class rather than inside the body
      // the hash digests, so the preview would not re-register without them.
      // Only a widget that declares a `sizeMode` carries them at all, and every
      // other one keeps the digest it had before they joined the hash.
      if (androidBranchesOnSize) 'sizes=${androidDeclaredSizes.join(',')}',
      // The emitted Glance source is the one serialization of the tree that
      // covers layout, styling and the values inlined into it.
      effectiveWidgetTree.toKotlin(
        0,
        dataExpr: 'data',
        context: androidEmitContext,
      ),
      for (final field in dataFields) _fieldFingerprint(field),
      for (final group in listDataGroups)
        'list(${group.key},${group.timed},'
            '${group.fields.map(_fieldFingerprint).join(',')})',
    ];
    final digest = fnv1a32(parts.join(_hashSeparator));
    return digest.toRadixString(16).padLeft(8, '0');
  }

  /// Every data field down to the type that carries values: time-based wrappers
  /// stripped and JSON paths descended.
  Iterable<HWDataType<dynamic>> get dataLeaves sync* {
    for (final field in dataFields) {
      yield* _leavesOf(field);
    }
  }

  static Iterable<HWDataType<dynamic>> _leavesOf(
    HWDataType<dynamic> field,
  ) sync* {
    switch (field) {
      case HWTimedData<dynamic>():
        yield* _leavesOf(field.data);
      case HWJson<dynamic>():
        yield* _leavesOf(field.child);
      default:
        yield field;
    }
  }

  static bool _hasPreviewValue(HWDataType<dynamic> leaf) => switch (leaf) {
        HWDateTime() => leaf.previewIso != null,
        HWImageData() => leaf.previewAsset != null,
        HWLocalizedString() => leaf.previewTranslations != null,
        _ => leaf.previewValue != null,
      };

  /// One field's contribution to [previewContentHash], spelled out rather than
  /// hashed through `toString`, which no data type promises.
  static String _fieldFingerprint(HWDataType<dynamic> field) {
    switch (field) {
      case HWTimedData<dynamic>():
        return 'timed(${_fieldFingerprint(field.data)})';
      case HWJson<dynamic>():
        return 'json(${field.key}>${_fieldFingerprint(field.child)})';
      case HWItemData<dynamic>():
        return 'item(${_fieldFingerprint(field.data)},'
            '${_previewValuesFingerprint(field.previewValues)})';
      case HWLocalizedString():
        return 'localized(${field.key},${field.isConstant},'
            '${_translationsFingerprint(field.defaultTranslations)},'
            '${_translationsFingerprint(field.previewTranslations)})';
      case HWImageData():
        return 'image(${field.rawKey},${field.effectiveAssetKey},'
            '${field.previewAsset})';
      case HWDateTime():
        return 'date(${field.key},${field.previewIso})';
      case HWIconData():
        final entries = [
          for (final entry in field.entries)
            '${entry.name}=${entry.codePoint}'
                '${entry.matchTextDirection ? '>rtl' : ''}',
        ];
        return 'icon(${field.key},${field.iconFont},${entries.join(',')},'
            '${field.defaultValue},${field.previewValue})';
      default:
        return '${field.runtimeType}(${field.key},${field.defaultValue},'
            '${field.previewValue})';
    }
  }

  /// [values] as a digest-stable string: locales sorted, so the same
  /// translations written in another order hash the same.
  static String _translationsFingerprint(Map<String, String>? values) {
    if (values == null) return '-';
    final entries = values.entries.map((e) => '${e.key}=${e.value}').toList()
      ..sort();
    return entries.join(_hashSeparator);
  }

  /// [values] as a digest-stable string, each entry tagged with its type so
  /// that `1`, `1.0` and `'1'` hash apart.
  static String _previewValuesFingerprint(List<Object>? values) {
    if (values == null) return '-';
    return values.map((v) => '${v.runtimeType}:$v').join(_hashSeparator);
  }

  /// [value] carrying the `homeWidget` query parameter.
  ///
  /// The plugin's iOS side only reports a click whose URL has that parameter,
  /// so it is appended on both platforms to keep the [Uri] the app sees
  /// identical. A value that already carries the parameter is left as it is.
  ///
  /// The parameter is spliced into the text rather than through
  /// [Uri.replace], which normalizes what it re-serializes — a `myApp://`
  /// scheme would come back lowercased, no longer matching what the author
  /// wrote and matches against.
  static String? _withHomeWidgetParam(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (uri.queryParametersAll.containsKey(_homeWidgetQueryParam)) return value;

    final fragmentStart = value.indexOf('#');
    final base =
        fragmentStart == -1 ? value : value.substring(0, fragmentStart);
    final fragment = fragmentStart == -1 ? '' : value.substring(fragmentStart);
    final separator = base.contains('?') ? '&' : '?';
    return '$base$separator$_homeWidgetQueryParam$fragment';
  }

  /// Query parameter marking a URL as coming from a widget click.
  static const String _homeWidgetQueryParam = 'homeWidget';

  /// Namespace for every platform resource this widget owns.
  String get resourcePrefix => widgetResourcePrefix(className);

  /// Namespace for every font file this widget owns.
  ///
  /// Held apart from [resourcePrefix] because the decoder stamps it onto every
  /// icon before a spec exists, so both have to be derived from the class name
  /// the same way.
  String get fontResourcePrefix => hwFontResourcePrefix(toSnakeCase(className));

  /// Every custom font file the widget renders text with.
  ///
  /// One entry per family, weight and slant the tree actually uses, which is
  /// what the generated per-widget font tables are built from.
  Set<HWFontVariant> get fontVariants => effectiveWidgetTree.fontVariants;

  /// Whether any text in the widget is drawn into a bitmap on Android, which
  /// is what the generated measuring pass is there for.
  bool get rendersAndroidBitmapText =>
      effectiveWidgetTree.rendersAndroidBitmapText;

  /// The icon fields this widget stores, wherever they are declared.
  ///
  /// Time-based and JSON wrappers are descended, so a field reaches this list
  /// however it is spelled, and the item fields of every list follow.
  List<HWIconData> get iconFields => [
        for (final field in dataFields)
          if (iconLeafOf(field) case final icon?) icon,
        for (final group in listDataGroups) ...group.iconFields,
      ];

  /// Every icon field paired with the dotted path saying where it is
  /// declared, `forecast[].condition` for an item field; a field with no
  /// resolved entry is left out.
  List<(String, HWIconData)> get _pathedIconFields => [
        for (final field in dataFields)
          if (iconLeafOf(field) case final icon?)
            if (icon.entries.isNotEmpty) (_iconFieldPath(field), icon),
        for (final group in listDataGroups)
          for (final icon in group.iconFields)
            if (icon.entries.isNotEmpty) ('${group.key}[].${icon.key}', icon),
      ];

  static String _iconFieldPath(HWDataType<dynamic> field) {
    final unwrapped = field.unwrapped;
    if (unwrapped is HWJson<dynamic>) {
      return [unwrapped.key, ...unwrapped.pathSegments].join('.');
    }
    return unwrapped.key;
  }

  /// The icon enums the generated Dart declares, by enum name, in first-seen
  /// order: fields sharing a leaf key share one enum, merged from the union
  /// of their entries.
  Map<String, HWIconData> get iconEnums {
    final merged = <String, HWIconData>{};
    final owners = <String, String>{};
    for (final (path, icon) in _pathedIconFields) {
      final name = icon.enumNameFor(className);
      final existing = merged[name];
      if (existing == null) {
        merged[name] = icon;
        owners[name] = path;
        continue;
      }
      merged[name] = _mergedIconEnum(
        name: name,
        into: existing,
        intoPath: owners[name]!,
        from: icon,
        fromPath: path,
      );
    }
    return merged;
  }

  /// Every glyph this widget may draw that mirrors in a right-to-left layout.
  ///
  /// Directionality is a property of the `IconData` constant rather than of
  /// the field holding it, so one set covers the whole widget and no field has
  /// to know which other fields share its enum.
  Set<int> get mirroredIconCodePoints => {
        for (final field in iconFields) ...field.mirroredCodePoints,
      };

  /// [into] carrying the entries of [from] as well, or a [GeneratorError] when
  /// the two describe the same enum value differently.
  static HWIconData _mergedIconEnum({
    required String name,
    required HWIconData into,
    required String intoPath,
    required HWIconData from,
    required String fromPath,
  }) {
    final shared = 'The icon fields "$intoPath" and "$fromPath" both generate '
        'the enum $name';
    if (into.iconFont == null || from.iconFont == null) {
      // coverage:ignore-start
      throw GeneratorError(
        '$shared, but at least one of them was never resolved to an icon font. '
        'Declare both of them in a @HomeWidget annotation.',
      );
      // coverage:ignore-end
    }
    if (into.iconFont != from.iconFont) {
      throw GeneratorError(
        '$shared, but draw their glyphs out of different fonts '
        '(${into.iconFont} and ${from.iconFont}). Give one of them a key of '
        'its own.',
      );
    }

    final entries = [...into.entries];
    for (final entry in from.entries) {
      final sameName = entries.indexWhere((e) => e.name == entry.name);
      if (sameName != -1) {
        if (entries[sameName].codePoint != entry.codePoint) {
          throw GeneratorError(
            '$shared, but name the icon "${entry.name}" after different '
            'glyphs (${_glyphLiteral(entries[sameName].codePoint)} and '
            '${_glyphLiteral(entry.codePoint)}). Give one of them a key of '
            'its own.',
          );
        }
        if (entries[sameName].matchTextDirection != entry.matchTextDirection) {
          final directionalPath =
              entries[sameName].matchTextDirection ? intoPath : fromPath;
          final steadyPath =
              entries[sameName].matchTextDirection ? fromPath : intoPath;
          throw GeneratorError(
            '$shared, but the icon "${entry.name}" is directional in '
            '"$directionalPath" and not in "$steadyPath". Give one of them '
            'a key of its own.',
          );
        }
        continue;
      }
      final sameGlyph =
          entries.indexWhere((e) => e.codePoint == entry.codePoint);
      if (sameGlyph != -1) {
        throw GeneratorError(
          '$shared, but give the glyph ${_glyphLiteral(entry.codePoint)} the '
          'names "${entries[sameGlyph].name}" and "${entry.name}". Only the '
          'codepoint is stored, so the widget could never tell them apart.',
        );
      }
      entries.add(entry);
    }

    // The merged enum is the union of what several fields declare, so neither
    // field's default nor its preview value belongs to it.
    return HWIconData.resolved(
      into.key,
      entries: entries,
      iconFont: into.iconFont!,
      defaultValue: null,
      previewValue: null,
    );
  }

  static String _glyphLiteral(int codePoint) =>
      '0x${codePoint.toRadixString(16).toUpperCase()}';

  /// Every icon glyph this widget can draw, per icon font.
  ///
  /// The tree's own icons plus every glyph [iconFields] may hold — a field the
  /// tree never renders still travels through `saveData`, and an icon font is
  /// subset down to exactly this set.
  Map<HWIconFont, Set<int>> get iconCodePoints {
    final glyphs = <HWIconFont, Set<int>>{};
    effectiveWidgetTree.iconCodePoints.forEach((font, codePoints) {
      glyphs.putIfAbsent(font, () => <int>{}).addAll(codePoints);
    });
    for (final field in iconFields) {
      final font = field.iconFont;
      if (font == null) continue;
      glyphs.putIfAbsent(font, () => <int>{}).addAll(field.codePoints);
    }
    return glyphs;
  }

  /// Resource holding the gallery title.
  String get labelResourceName => '${resourcePrefix}_label';

  /// Resource holding the gallery description.
  String get descriptionResourceName => '${resourcePrefix}_description';

  /// Every locale this widget ships text for, default locale first.
  List<String> get supportedLocales {
    final configured = data.localization?.supportedLocales ?? const <String>[];
    final locales = <String>{defaultLocale, ...configured};
    return locales.toList();
  }

  /// The gallery title in the default locale, where
  /// `localization.name[defaultLocale]` wins over the top-level `name`.
  String get galleryName =>
      _defaultLocaleText(data.localization?.name) ?? data.name;

  /// The gallery description in the default locale, or null when there is none.
  String? get galleryDescription =>
      _defaultLocaleText(data.localization?.description) ??
      _nonEmpty(data.description);

  /// [values] minus the default locale, which lives in the base resource.
  Map<String, String>? galleryTranslations(Map<String, String>? values) {
    if (values == null) return null;
    return {
      for (final entry in values.entries)
        if (entry.key != defaultLocale) entry.key: entry.value,
    };
  }

  String? _defaultLocaleText(Map<String, String>? values) =>
      _nonEmpty(values?[defaultLocale]);

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  /// Whether the gallery name or description carries translations.
  bool get hasLocalizedGalleryStrings {
    final localization = data.localization;
    if (localization == null) return false;
    return (localization.name?.isNotEmpty ?? false) ||
        (localization.description?.isNotEmpty ?? false);
  }

  /// The locale anchoring every fallback chain, or `en` when unset.
  ///
  /// Validation requires `localization:` whenever a localized string exists, so
  /// the fallback only applies to widgets that use none.
  String get defaultLocale => data.localization?.defaultLocale ?? 'en';

  /// Time-based [dataFields], in declaration order.
  ///
  /// An item field of a time-based list is not one: it belongs to the list.
  List<HWTimedData<dynamic>> get timedDataFields => dataFields
      .whereType<HWTimedData<dynamic>>()
      .where((field) => field.data is! HWItemData)
      .toList();

  /// Whether the widget stores anything time-based: a [timedDataFields] entry
  /// or a time-based list.
  bool get hasTimedData =>
      timedDataFields.isNotEmpty || timedListGroups.isNotEmpty;

  /// Timed fields wrapping a non-[HWJson] type, unwrapped to the inner type.
  List<HWDataType<dynamic>> get timedPrimitiveDataFields => [
        for (final field in timedDataFields)
          if (field.data is! HWJson) field.data,
      ];

  /// Timed [HWJson] fields grouped by root key, mirroring [jsonDataGroups].
  ///
  /// These groups are intentionally absent from [jsonDataGroups]; native
  /// generators must emit their nested structs/classes from here.
  List<JsonDataGroup> get timedJsonDataGroups => _groupJsonFields(
        timedDataFields.map((f) => f.data).whereType<HWJson<dynamic>>(),
      );

  /// Image [dataFields], runtime and asset alike, time-based ones unwrapped.
  List<HWImageData> get imageDataFields => [
        for (final field in dataFields)
          if (field.unwrapped case final HWImageData image) image,
      ];

  /// Runtime images declared as a time-based top-level data field.
  ///
  /// Their `ImageProvider`s travel per timestamp inside the generated timed
  /// data class, and each one is written to its own PNG keyed
  /// `<prefix>.timedData.<key>.<epochMillis>`.
  List<HWImageData> get timedImageFields => [
        for (final field in timedDataFields)
          if (field.unwrapped case final HWImageData image) image,
      ];

  /// Image fields supplied at runtime through the generated `saveData`.
  List<HWImageData> get runtimeImageFields =>
      imageDataFields.where((f) => !f.isAsset).toList();

  /// Flutter asset images, read in place from the app bundle by native code.
  List<HWImageData> get assetImageFields =>
      imageDataFields.where((f) => f.isAsset).toList();

  /// Every native helper the generated widget sources have to declare, each
  /// one after the helpers it calls.
  ///
  /// The widget tree names the helpers it renders through — decoding a picture,
  /// formatting a number — and every declared field the helpers reading it back
  /// — a date the widget never shows is still parsed into the data class. This
  /// is the one source of truth for what a generated file declares, so a field
  /// nothing displays never drags a render helper in. Both are handed to
  /// [resolveNativeHelpers], which closes over their dependencies.
  List<HWNativeHelper> get nativeHelpers => resolveNativeHelpers([
        ...effectiveWidgetTree.nativeHelpers,
        for (final field in dataFields) ...field.nativeHelpers,
      ]);

  /// Image leaves of the untimed JSON groups.
  List<JsonImageField> get jsonImageFields => _jsonImages(jsonDataGroups);

  /// Image leaves of the timed JSON groups, whose PNGs are additionally keyed
  /// by the timestamp of the entry they belong to.
  List<JsonImageField> get timedJsonImageFields =>
      _jsonImages(timedJsonDataGroups);

  /// Whether any image reaches the widget through the generated `saveData`,
  /// wherever it is declared.
  ///
  /// Drives the `ImageProvider` import of the generated Dart helper.
  bool get hasRuntimeImages =>
      runtimeImageFields.isNotEmpty ||
      jsonImageFields.isNotEmpty ||
      timedJsonImageFields.isNotEmpty ||
      listImageFields.isNotEmpty;

  /// The image fields of every list, time-based ones included.
  List<ListImageField> get listImageFields => [
        for (final group in listDataGroups)
          for (final image in group.imageFields)
            ListImageField(
              listKey: group.key,
              timed: group.timed,
              image: image,
            ),
      ];

  /// Every Flutter asset an item image previews with, once each, in first-seen
  /// order: the `previewAsset` of an image field and each of its
  /// `previewValues`.
  List<ListPreviewAsset> get listPreviewAssets {
    final references = [
      for (final group in listDataGroups)
        for (final field in group.fields)
          if (imageLeafOf(field) case final image?) ...[
            if (image.previewAsset case final asset?)
              ListPreviewAsset(
                listKey: group.key,
                fieldKey: image.key,
                asset: asset,
              ),
            for (final (index, value) in (field.previewValues ?? []).indexed)
              if (value is String)
                ListPreviewAsset(
                  listKey: group.key,
                  fieldKey: image.key,
                  index: index,
                  asset: value,
                ),
          ],
    ];
    final seen = <String>{};
    return [
      for (final reference in references)
        if (seen.add(reference.asset)) reference,
    ];
  }

  List<JsonImageField> _jsonImages(List<JsonDataGroup> groups) => [
        for (final group in groups)
          for (final child in group.children)
            if (child.type case final HWImageData image)
              JsonImageField(
                rootKey: group.key,
                path: child.path,
                image: image,
              ),
      ];

  /// JSON fields grouped by root key for nested native struct generation.
  List<JsonDataGroup> get jsonDataGroups =>
      _groupJsonFields(dataFields.whereType<HWJson<dynamic>>());

  List<JsonDataGroup> _groupJsonFields(Iterable<HWJson<dynamic>> fields) {
    final orderedKeys = <String>[];
    final grouped = <String, List<HWJson<dynamic>>>{};

    for (final field in fields) {
      final declarations = grouped.putIfAbsent(field.key, () {
        orderedKeys.add(field.key);
        return <HWJson<dynamic>>[];
      });
      // Two declarations of one path carry one merged leaf, the same way
      // [dataFields] folds top-level keys together. The whole [HWJson] decides,
      // not its leaf, so the rule that a leaf default has to agree lives in one
      // place. Incompatible declarations are kept apart so the validator's path
      // trie reports the conflict.
      final duplicate =
          declarations.indexWhere((e) => e.isCompatibleWith(field));
      if (duplicate != -1) {
        // coverage:ignore-start
        declarations[duplicate] =
            declarations[duplicate].mergedWith(field) as HWJson<dynamic>;
        continue;
        // coverage:ignore-end
      }
      declarations.add(field);
    }

    return [
      for (final key in orderedKeys)
        JsonDataGroup(
          key: key,
          children: [
            for (final declaration in grouped[key]!)
              JsonDataField(
                path: declaration.pathSegments,
                type: declaration.leafType,
              ),
          ],
        ),
    ];
  }

  /// Every `HWColumn.builder` and `HWRow.builder` in the tree, in document
  /// order, both platforms' included.
  ///
  /// One builder written into two places is one declaration.
  List<ListDeclaration> get declaredLists {
    final declarations = <ListDeclaration>[];
    for (final widget in effectiveWidgetTree.descendants) {
      if (widget is! HWMultiChildWidget) continue;
      final key = widget.list;
      if (key == null) continue;
      if (declarations.any((other) => identical(other.builder, widget))) {
        continue;
      }
      declarations.add(
        ListDeclaration(key: key, builder: widget, reads: widget.itemReads),
      );
    }
    return declarations;
  }

  /// The lists the widget stores, one per key in first-seen order, each
  /// holding the item fields every builder over it reads.
  ///
  /// Derived from the tree alone: a list is never one of [dataFields].
  List<ListDataGroup> get listDataGroups {
    final keys = <String>[];
    final grouped = <String, List<ListDeclaration>>{};
    for (final declaration in declaredLists) {
      grouped.putIfAbsent(declaration.key, () {
        keys.add(declaration.key);
        return <ListDeclaration>[];
      }).add(declaration);
    }

    return [
      for (final key in keys) _listDataGroup(key, grouped[key]!),
    ];
  }

  static ListDataGroup _listDataGroup(
    String key,
    List<ListDeclaration> declarations,
  ) {
    final reads = [
      for (final declaration in declarations) ...declaration.reads,
    ];
    final fields = <HWItemData<dynamic>>[];
    for (final read in reads) {
      final field = read.unwrapped as HWItemData<dynamic>;
      final existing = fields.indexWhere((f) => f.isCompatibleWith(field));
      if (existing == -1) {
        fields.add(field);
        continue;
      }
      fields[existing] =
          fields[existing].mergedWith(field) as HWItemData<dynamic>;
    }
    return ListDataGroup(
      key: key,
      timed: reads.any((read) => read is HWTimedData),
      fields: fields,
      declarations: declarations,
    );
  }

  /// The [listDataGroups] stored under a preferences key of their own.
  List<ListDataGroup> get untimedListGroups =>
      listDataGroups.where((group) => !group.timed).toList();

  /// The [listDataGroups] traveling inside the entries of the timed data
  /// file.
  List<ListDataGroup> get timedListGroups =>
      listDataGroups.where((group) => group.timed).toList();
}
