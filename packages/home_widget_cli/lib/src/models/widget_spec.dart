import 'package:home_widget_generator/home_widget_generator.dart';

import '../util/naming.dart';

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

/// Specification for a home widget.
class WidgetSpec {
  /// The annotated configuration data.
  final HomeWidget data;

  /// The name of the Dart class (from annotated class).
  final String className;

  /// The data fields defined in the annotation.
  final List<HWDataType<dynamic>> dataFields;

  /// The widget tree definition (if any).
  final HWWidget? widgetTree;

  /// Creates a new [WidgetSpec].
  const WidgetSpec({
    required this.data,
    required this.className,
    this.dataFields = const [],
    this.widgetTree,
  });
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSpec &&
          data == other.data &&
          className == other.className &&
          dataFields == other.dataFields &&
          widgetTree == other.widgetTree;

  @override
  int get hashCode =>
      data.hashCode ^
      className.hashCode ^
      dataFields.hashCode ^
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
          HWRow(
            children: [
              HWText.fixed('${field.key}: '),
              HWText(field),
            ],
          ),
      ],
    );
  }

  /// Non-JSON, non-timed [dataFields] (primitives and simple types).
  ///
  /// Constant localized strings are excluded: they are inlined into the widget
  /// body and must never reach the data class, preferences or `saveData`.
  List<HWDataType<dynamic>> get primitiveDataFields => dataFields
      .where((f) => f is! HWJson && f is! HWTimedData)
      .where((f) => !(f is HWLocalizedString && f.isConstant))
      .toList();

  /// Every localized string declared as a top-level data field.
  List<HWLocalizedString> get localizedStrings =>
      dataFields.whereType<HWLocalizedString>().toList();

  /// Localized strings sitting at the leaf of a JSON path, which supply the
  /// fallback used when the path resolves to nothing.
  List<HWLocalizedString> get jsonLocalizedStrings => [
        for (final field in dataFields.whereType<HWJson>())
          if (field.leafType case final HWLocalizedString leaf) leaf,
      ];

  /// Every localized string this widget carries, wherever it is declared.
  List<HWLocalizedString> get allLocalizedStrings => [
        ...localizedStrings,
        ...jsonLocalizedStrings,
      ];

  /// Localized strings backed by a data field, i.e. overridable at runtime.
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

  /// Whether the generated native code needs the locale-resolution helpers.
  ///
  /// Constants and gallery strings do not: they are platform resources,
  /// resolved by the OS.
  bool get needsLocaleHelpers =>
      keyedLocalizedStrings.isNotEmpty || jsonLocalizedStrings.isNotEmpty;

  /// Whether the generated native code reads a translation blob back out of
  /// preferences, which only keyed data fields do.
  bool get needsLocalizedRead => keyedLocalizedStrings.isNotEmpty;

  /// Whether the widget resolves any text itself, and so goes stale on a system
  /// language change unless it re-renders.
  bool get rendersLocalizedContent =>
      constantLocalizedStrings.isNotEmpty || needsLocaleHelpers;

  /// Namespace for every platform resource this widget owns.
  String get resourcePrefix => widgetResourcePrefix(className);

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

  /// Time-based [dataFields], ordered and de-duplicated.
  List<HWTimedData<dynamic>> get timedDataFields {
    final result = <HWTimedData<dynamic>>[];
    for (final field in dataFields.whereType<HWTimedData<dynamic>>()) {
      if (!result.contains(field)) {
        result.add(field);
      }
    }
    return result;
  }

  /// Timed fields wrapping a non-[HWJson] type, unwrapped to the inner type.
  ///
  /// Ordered and de-duplicated, mirroring [timedDataFields].
  List<HWDataType<dynamic>> get timedPrimitiveDataFields => [
        for (final field in timedDataFields)
          if (field.data is! HWJson) field.data,
      ];

  /// Timed [HWJson] fields grouped by root key, mirroring [jsonDataGroups].
  ///
  /// These groups are intentionally absent from [jsonDataGroups]; native
  /// generators must emit their nested structs/classes from here.
  List<JsonDataGroup> get timedJsonDataGroups => _groupJsonFields(
        timedDataFields.map((f) => f.data).whereType<HWJson>(),
      );

  /// JSON fields grouped by root key for nested native struct generation.
  List<JsonDataGroup> get jsonDataGroups {
    final orderedKeys = <String>[];
    final groupedChildren = <String, List<JsonDataField>>{};

    for (final field in dataFields.whereType<HWJson>()) {
      if (!orderedKeys.contains(field.key)) {
        orderedKeys.add(field.key);
        groupedChildren[field.key] = <JsonDataField>[];
      }

      final leafType = field.leafType;
      final path = field.pathSegments;
      final existing = groupedChildren[field.key]!;
      if (existing.any((e) => _samePath(e.path, path) && e.type == leafType)) {
        continue;
      }
      groupedChildren[field.key]!.add(
        JsonDataField(
          path: path,
          type: leafType,
        ),
      );
    }

    return [
      for (final key in orderedKeys)
        JsonDataGroup(
          key: key,
          children: groupedChildren[key]!,
        ),
    ];
  }

  List<JsonDataGroup> _groupJsonFields(Iterable<HWJson> fields) {
    final orderedKeys = <String>[];
    final groupedChildren = <String, List<JsonDataField>>{};

    for (final field in fields) {
      if (!orderedKeys.contains(field.key)) {
        orderedKeys.add(field.key);
        groupedChildren[field.key] = <JsonDataField>[];
      }

      final leafType = field.leafType;
      final path = field.pathSegments;
      final existing = groupedChildren[field.key]!;
      if (existing.any((e) => _samePath(e.path, path) && e.type == leafType)) {
        continue;
      }
      groupedChildren[field.key]!.add(
        JsonDataField(
          path: path,
          type: leafType,
        ),
      );
    }

    return [
      for (final key in orderedKeys)
        JsonDataGroup(
          key: key,
          children: groupedChildren[key]!,
        ),
    ];
  }

  bool _samePath(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
