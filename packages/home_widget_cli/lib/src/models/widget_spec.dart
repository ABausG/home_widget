import 'package:home_widget_generator/home_widget_generator.dart';

import '../util/fnv_hash.dart';
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

/// Separator between the parts [WidgetSpec.previewContentHash] digests.
///
/// Do not change it: the digest it produces is what decides whether a launcher
/// re-renders a preview.
final String _hashSeparator = String.fromCharCode(31);

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
  const WidgetSpec({
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

  /// Non-JSON, non-timed [dataFields] (primitives and simple types).
  ///
  /// Includes runtime [HWImageData], whose stored value is the nullable path
  /// string that native code reads from UserDefaults / SharedPreferences.
  ///
  /// Constant localized strings are excluded: they are inlined into the widget
  /// body and must never reach the data class, preferences or `saveData`.
  /// Asset images are excluded too: native code reads them straight out of the
  /// app bundle, so they are never stored.
  List<HWDataType<dynamic>> get primitiveDataFields => dataFields
      .where((f) => f is! HWJson && f is! HWTimedData)
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

  /// Every localized string this widget carries, wherever it is declared.
  List<HWLocalizedString> get allLocalizedStrings => [
        ...localizedStrings,
        ...timedLocalizedStrings,
        ...jsonLocalizedStrings,
        ...timedJsonLocalizedStrings,
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

  /// Whether the generated native code needs the locale-resolution helpers.
  ///
  /// Constants and gallery strings do not: they are platform resources,
  /// resolved by the OS. Everything else the widget matches itself, time-based
  /// values included — being time-based changes where the translations come
  /// from, not who resolves them.
  bool get needsLocaleHelpers => allLocalizedStrings.any((f) => !f.isConstant);

  /// Whether the generated native code reads a translation blob back out of
  /// the preferences key of a data field, which only untimed keyed fields do.
  bool get needsLocalizedRead => keyedLocalizedStrings.isNotEmpty;

  /// Whether the generated native code reads a translation map out of the
  /// timed entry that is active at render time.
  bool get needsTimedLocalizedRead => timedLocalizedStrings.isNotEmpty;

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
  /// stored data, wherever it is declared.
  bool get hasPreviewValues => dataLeaves.any(_hasPreviewValue);

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
      // The emitted Glance source is the one serialization of the tree that
      // covers layout, styling and the values inlined into it.
      effectiveWidgetTree.toKotlin(0, dataExpr: 'data'),
      for (final field in dataFields) _fieldFingerprint(field),
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
      case HWLocalizedString():
        return 'localized(${field.key},${field.isConstant},'
            '${_translationsFingerprint(field.defaultTranslations)},'
            '${_translationsFingerprint(field.previewTranslations)})';
      case HWImageData():
        return 'image(${field.rawKey},${field.effectiveAssetKey},'
            '${field.previewAsset})';
      case HWDateTime():
        return 'date(${field.key},${field.previewIso})';
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
  List<HWTimedData<dynamic>> get timedDataFields =>
      dataFields.whereType<HWTimedData<dynamic>>().toList();

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
  /// The widget tree names the helpers it renders through, and every declared
  /// field the helpers reading it back -- a date the widget never shows is
  /// still parsed into the data class. This resolves both to their transitive
  /// closure, so a generator can emit `helper.swift` / `helper.kotlin` down
  /// the list and every call is already in scope. Ordering breaks ties by
  /// name, so the same widget always generates the same file.
  List<HWNativeHelper> get nativeHelpers {
    final closure = <String, HWNativeHelper>{};
    void collect(HWNativeHelper helper) {
      if (closure.containsKey(helper.name)) return;
      closure[helper.name] = helper;
      helper.dependencies.forEach(collect);
    }

    effectiveWidgetTree.nativeHelpers.forEach(collect);
    for (final field in dataFields) {
      field.nativeHelpers.forEach(collect);
    }

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
      timedJsonImageFields.isNotEmpty;

  /// Whether the widget renders any image at all, asset images included.
  ///
  /// Drives the shared native decode helpers, which both routes go through.
  bool get hasImages => imageDataFields.isNotEmpty || hasRuntimeImages;

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
        declarations[duplicate] =
            declarations[duplicate].mergedWith(field) as HWJson<dynamic>;
        continue;
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
}
