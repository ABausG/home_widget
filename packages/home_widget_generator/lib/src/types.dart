import 'package:meta/meta.dart';

import 'fonts.dart';
import 'formats.dart';
import 'generator_error.dart';
import 'native_helpers.dart';
import 'utils/content_hash.dart';
import 'utils/map_equals.dart';
import 'utils/string_literals.dart';

/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
sealed class HWDataType<T> {
  final String key;
  const HWDataType(this.key);

  /// The default value.
  T? get defaultValue;

  /// The sample value the widget gallery shows for this key.
  ///
  /// Only ever rendered in a preview: the widget itself falls back to
  /// [defaultValue] as before.
  T? get previewValue;

  /// The Dart type string.
  String get dartType;

  /// The type the generated Dart API hands this value over as; defaults to
  /// [dartType].
  String dartApiType(String widgetClassName) => dartType;

  /// The type the generated `getData` hands this value back as; defaults to
  /// [dartApiType].
  String dartGetDataType(String widgetClassName) =>
      dartApiType(widgetClassName);

  /// [expr], which reads this value in its stored form, mapped to
  /// [dartApiType].
  String dartDecode(String expr, String widgetClassName) => expr;

  /// [expr], which holds this value as [dartApiType] and is only evaluated
  /// when non-null, written back into its stored form; null when the two are
  /// the same.
  String? dartEncode(String expr, String widgetClassName) => null;

  /// Dart literal representing [defaultValue] for generated Dart code, or null
  /// when there is no default.
  String? codegenDartDefaultLiteral() {
    final value = defaultValue;
    if (value == null) return null;
    if (value is String) return "'${escapeDartStringLiteral(value)}'";
    return '$value';
  }

  /// The Kotlin type string.
  String get kotlinType;

  /// The Swift type string.
  String get swiftType;

  /// Returns the Kotlin code to read this value from SharedPreferences.
  /// [store] is the variable name of the SharedPreferences instance (e.g. "prefs").
  /// [key] is the full key string (e.g. "${PREFERENCES_PREFIX}.count").
  /// [preview] reads for the widget gallery, where a stored value still wins
  /// but [previewValue] takes the place of [defaultValue] behind it.
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  });

  /// Returns the Swift code to read this value from UserDefaults.
  /// [store] is the variable name of the UserDefaults instance (e.g. "defaults").
  /// [key] is the full key string.
  /// [preview] behaves as in [androidReadValue].
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  });

  /// Returns the Kotlin code to stringify this value for display.
  /// [outerValue] is the nullable value expression (e.g. "data.count").
  /// [innerValue] is the non-null value expression (e.g. "data.count").
  String androidToString({
    required String outerValue,
    required String innerValue,
  });

  /// Returns the Swift code to stringify this value for display.
  /// [outerValue] is the nullable value expression (e.g. "entry.data.count").
  /// [innerValue] is the non-null value expression (e.g. "entry.data.count!").
  String iosToString({required String outerValue, required String innerValue});

  /// Returns the Swift access expression for this value from [dataExpr].
  String swiftAccess(String dataExpr) => '$dataExpr.$key';

  /// Returns the Kotlin access expression for this value from [dataExpr].
  String kotlinAccess(String dataExpr) => '$dataExpr.$key';

  /// Kotlin expression applying widget JSON leaf defaults ([HWJson] only).
  String kotlinReadExpr(String dataExpr) => kotlinAccess(dataExpr);

  /// Swift expression applying widget JSON leaf defaults ([HWJson] only).
  String swiftReadExpr(String dataExpr) => swiftAccess(dataExpr);

  /// Kotlin literal representing [defaultValue] for generated native code,
  /// or null when there is no default.
  String? codegenKotlinDefaultLiteral() => null; // coverage:ignore-line

  /// Swift literal representing [defaultValue] for generated native code,
  /// or null when there is no default.
  String? codegenSwiftDefaultLiteral() => null; // coverage:ignore-line

  /// Kotlin literal representing [previewValue] for generated native code,
  /// or null when there is no preview value.
  String? codegenKotlinPreviewLiteral() => null; // coverage:ignore-line

  /// Swift literal representing [previewValue] for generated native code,
  /// or null when there is no preview value.
  String? codegenSwiftPreviewLiteral() => null; // coverage:ignore-line

  /// Kotlin literal a generated read falls back on when the store holds
  /// nothing: [codegenKotlinPreviewLiteral] in a [preview] that has one,
  /// [codegenKotlinDefaultLiteral] otherwise, and null when there is neither.
  String? codegenKotlinFallbackLiteral({bool preview = false}) =>
      (preview ? codegenKotlinPreviewLiteral() : null) ??
      codegenKotlinDefaultLiteral();

  /// Swift counterpart of [codegenKotlinFallbackLiteral].
  String? codegenSwiftFallbackLiteral({bool preview = false}) =>
      (preview ? codegenSwiftPreviewLiteral() : null) ??
      codegenSwiftDefaultLiteral();

  /// This type with any time-based wrapper removed.
  ///
  /// Returns `this` for every variant except [HWTimedData], which returns the
  /// type it wraps. Use this wherever code needs to branch on the concrete
  /// data variant (for example `is HWJson`) regardless of whether the field is
  /// time-based. An [HWItemData] stays itself, since it reads from a list item
  /// rather than from the widget's data.
  HWDataType<dynamic> get unwrapped => this;

  /// The value type this field ultimately describes.
  ///
  /// Strips an [HWTimedData] or [HWItemData] wrapper and descends an [HWJson]
  /// to its leaf, so a plain, time-based, JSON-nested or item field answers
  /// with the same [HWInt], [HWImageData] or [HWBool]; `this` for every plain
  /// type.
  HWDataType<dynamic> get leaf => this;

  /// The native functions reading a stored value of this type back out of its
  /// own preferences key.
  ///
  /// Empty for the types native code reads straight out of the store; a field
  /// traveling as an encoded string names the helper decoding it, so it
  /// reaches the generated file even when nothing displays the value.
  /// Rendering helpers are named by the widget that renders, not here.
  List<HWNativeHelper> get nativeHelpers => const [];

  /// [nativeHelpers] for a read out of the timed entry active at render time,
  /// which is where an [HWTimedData] field's value comes from instead of a
  /// preferences key.
  ///
  /// Mirrors the [androidReadValue] / `androidTimedReadValue` split: a type
  /// that reads the same way from either place inherits the default.
  List<HWNativeHelper> get timedNativeHelpers => nativeHelpers;

  /// [nativeHelpers] for a read as a leaf of a decoded JSON group, mirroring
  /// the [androidReadValue] / `androidJsonReadValue` split.
  List<HWNativeHelper> get jsonNativeHelpers => nativeHelpers;

  /// The native functions called to display a value of this type, before their
  /// own dependencies are resolved.
  ///
  /// Empty for the types shown exactly as they were read; a type whose
  /// [kotlinReadExpr] / [swiftReadExpr] puts the value through a native
  /// function names it here, and the widget rendering the value folds these
  /// into its own `renderHelpers` — so a field nothing displays never drags one
  /// in.
  Set<HWNativeHelper> get renderHelpers => const {};

  /// [renderHelpers] for a value displayed out of a decoded JSON group,
  /// mirroring the [nativeHelpers] / [jsonNativeHelpers] split.
  Set<HWNativeHelper> get jsonRenderHelpers => renderHelpers;

  /// Whether [other] describes the same field as this one.
  ///
  /// Two declarations of a key are compatible when they are the same kind of
  /// field and every optional value they both set agrees; a value set on one
  /// side only is carried over by [mergedWith].
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      runtimeType == other.runtimeType &&
      key == other.key &&
      _mergeable(defaultValue, other.defaultValue) &&
      _mergeable(previewValue, other.previewValue);

  /// This field carrying the values set by either declaration.
  ///
  /// Throws a [GeneratorError] when [other] is not [isCompatibleWith] this.
  /// [other] is untyped so that a mismatched pair reaches that error rather
  /// than failing the argument's own type check first.
  HWDataType<T> mergedWith(HWDataType<dynamic> other) {
    if (!isCompatibleWith(other)) {
      throw GeneratorError(
        'Conflicting declarations for data key "$key": $runtimeType and '
        '${other.runtimeType} describe different fields.',
      );
    }
    return _merged(other);
  }

  /// [mergedWith] once [other] is known to be compatible, and so to be of this
  /// same type.
  HWDataType<T> _merged(HWDataType<dynamic> other);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWDataType &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          defaultValue == other.defaultValue &&
          previewValue == other.previewValue;

  @override
  int get hashCode => Object.hash(key, defaultValue, previewValue);
}

/// Whether two declarations of the same optional value can be merged: they
/// agree, or only one of them sets it.
bool _mergeable(Object? a, Object? b) => a == null || b == null || a == b;

class HWString extends HWDataType<String> {
  @override
  final String? defaultValue;

  @override
  final String? previewValue;

  const HWString(super.key, {this.defaultValue, this.previewValue});

  /// A string whose shipped value differs per locale, and which can additionally
  /// be overridden per locale at runtime via the generated `saveData`.
  ///
  /// [defaultTranslations] maps locale tag to text and must include the
  /// widget's `defaultLocale`. At render time each of the user's preferred
  /// languages is tried in order — exact tag (`pt-PT`), then language (`pt`),
  /// then any key sharing that language with a different region or script
  /// (`pt-BR`) — before falling back to the default locale.
  ///
  /// [previewTranslations] is the sample text the widget gallery shows, in the
  /// same shape.
  ///
  /// A const factory, so it is usable inside a `@HomeWidget(...)` annotation.
  const factory HWString.localized(
    String key, {
    required Map<String, String> defaultTranslations,
    Map<String, String>? previewTranslations,
  }) = HWLocalizedString;

  @override
  String get dartType => 'String';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    return '$store.getString("$key", $fallback)';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.string(forKey: "$key")';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '$outerValue ?: ""';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue ?? ""';
  }

  @override
  String? codegenKotlinDefaultLiteral() {
    final d = defaultValue;
    if (d == null) return null;
    return '"${escapeKotlinStringLiteral(d)}"';
  }

  @override
  String? codegenSwiftDefaultLiteral() {
    final d = defaultValue;
    if (d == null) return null;
    return '"${escapeSwiftStringLiteral(d)}"';
  }

  @override
  String? codegenKotlinPreviewLiteral() {
    final p = previewValue;
    if (p == null) return null;
    return '"${escapeKotlinStringLiteral(p)}"';
  }

  @override
  String? codegenSwiftPreviewLiteral() {
    final p = previewValue;
    if (p == null) return null;
    return '"${escapeSwiftStringLiteral(p)}"';
  }

  @override
  HWString _merged(HWDataType<dynamic> other) {
    final string = other as HWString;
    return HWString(
      key,
      defaultValue: defaultValue ?? string.defaultValue,
      previewValue: previewValue ?? string.previewValue,
    );
  }
}

/// A [HWString] whose shipped value differs per locale.
///
/// Two flavours, distinguished by [isConstant]: **keyed**
/// (`HWString.localized`) is a real data field whose compiled
/// [defaultTranslations] can be overridden at runtime via `saveData`;
/// **constant** (`HWText.localized`) ships as a platform string resource keyed
/// by [resourceName] and never reaches the data class.
///
/// [defaultLocale] and [resourcePrefix] are stamped on by the parser, not
/// written by the annotation author.
class HWLocalizedString extends HWString {
  /// Locale tag (`en`, `pt-BR`) to shipped text.
  final Map<String, String> defaultTranslations;

  /// Locale tag to sample text for the widget gallery, or null when the string
  /// previews with its [defaultTranslations].
  final Map<String, String>? previewTranslations;

  /// True when this string is inlined at build time rather than data-backed.
  final bool isConstant;

  /// The widget's default locale, stamped on by the parser. Null in
  /// annotation-space, where it is not knowable.
  final String? defaultLocale;

  /// Namespace for [resourceName], stamped on by the parser as
  /// `home_widget_<snake_widget_class>`.
  ///
  /// Null in annotation-space: a const constructor cannot know which widget it
  /// ends up in.
  final String? resourcePrefix;

  const HWLocalizedString(
    super.key, {
    required this.defaultTranslations,
    this.previewTranslations,
  })  : isConstant = false,
        defaultLocale = null,
        resourcePrefix = null;

  /// Rebuilt by the parser with [defaultLocale] and [resourcePrefix] resolved.
  @internal
  const HWLocalizedString.resolved(
    super.key, {
    required this.defaultTranslations,
    required this.isConstant,
    required this.defaultLocale,
    this.previewTranslations,
    this.resourcePrefix,
  });

  /// The platform string resource holding this constant's translations:
  /// `home_widget_<snake_widget_class>_t_<hash>`, where the hash is a
  /// [localizedContentHash] of the translations.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code. Not
  /// marked `@internal` because that package is a separate one and would then
  /// fail its own analyze.
  String get resourceName =>
      '${resourcePrefix ?? 'home_widget'}_t_${localizedContentHash(defaultTranslations)}';

  /// The locale the generated resolver falls back to; first entry when no
  /// default locale was stamped (validation rejects that in real generation).
  ///
  /// Codegen-internal; see [resourceName].
  String get baseLocaleTag => _baseLocaleTagOf(defaultTranslations);

  /// The base-locale text.
  ///
  /// Codegen-internal; see [resourceName].
  String get baseValue => defaultTranslations[baseLocaleTag] ?? '';

  /// [baseLocaleTag] of [previewTranslations], or null without them.
  ///
  /// Codegen-internal; see [resourceName].
  String? get previewBaseLocaleTag {
    final translations = previewTranslations;
    return translations == null ? null : _baseLocaleTagOf(translations);
  }

  /// The base-locale preview text, or null without [previewTranslations].
  ///
  /// Codegen-internal; see [resourceName].
  String? get previewBaseValue {
    final translations = previewTranslations;
    if (translations == null) return null;
    return translations[_baseLocaleTagOf(translations)] ?? '';
  }

  String _baseLocaleTagOf(Map<String, String> translations) {
    final locale = defaultLocale;
    if (locale != null && translations.containsKey(locale)) return locale;
    return translations.keys.isEmpty ? '' : translations.keys.first;
  }

  /// `mapOf("en" to "Hello", "de" to "Hallo")`
  @internal
  String get kotlinMapLiteral => _kotlinMapLiteralOf(defaultTranslations);

  /// `["en": "Hello", "de": "Hallo"]`
  @internal
  String get swiftMapLiteral => _swiftMapLiteralOf(defaultTranslations);

  /// [kotlinMapLiteral] of [previewTranslations], or null without them.
  ///
  /// Codegen-internal; see [resourceName].
  String? get kotlinPreviewMapLiteral {
    final translations = previewTranslations;
    return translations == null ? null : _kotlinMapLiteralOf(translations);
  }

  /// [swiftMapLiteral] of [previewTranslations], or null without them.
  ///
  /// Codegen-internal; see [resourceName].
  String? get swiftPreviewMapLiteral {
    final translations = previewTranslations;
    return translations == null ? null : _swiftMapLiteralOf(translations);
  }

  static String _kotlinMapLiteralOf(Map<String, String> translations) {
    if (translations.isEmpty) return 'emptyMap()';
    final entries = translations.entries
        .map(
          (e) => '"${escapeKotlinStringLiteral(e.key)}" to '
              '"${escapeKotlinStringLiteral(e.value)}"',
        )
        .join(', ');
    return 'mapOf($entries)';
  }

  static String _swiftMapLiteralOf(Map<String, String> translations) {
    if (translations.isEmpty) return '[:]';
    final entries = translations.entries
        .map(
          (e) => '"${escapeSwiftStringLiteral(e.key)}": '
              '"${escapeSwiftStringLiteral(e.value)}"',
        )
        .join(', ');
    return '[$entries]';
  }

  /// The compiled translations a read resolves against, and the locale it falls
  /// back to: [previewTranslations] in a [preview] that has them, otherwise
  /// [defaultTranslations].
  ///
  /// The stored locale map still wins over both, so a preview shows real data
  /// once there is some.
  (String, String) _kotlinCompiled({required bool preview}) =>
      preview && previewTranslations != null
          ? (
              kotlinPreviewMapLiteral!,
              escapeKotlinStringLiteral(previewBaseLocaleTag!)
            )
          : (kotlinMapLiteral, escapeKotlinStringLiteral(baseLocaleTag));

  /// Swift counterpart of [_kotlinCompiled].
  (String, String) _swiftCompiled({required bool preview}) =>
      preview && previewTranslations != null
          ? (
              swiftPreviewMapLiteral!,
              escapeSwiftStringLiteral(previewBaseLocaleTag!)
            )
          : (swiftMapLiteral, escapeSwiftStringLiteral(baseLocaleTag));

  /// A constant is a platform resource the OS resolves, so it needs nothing;
  /// every other string is merged and resolved by the widget itself.
  @override
  List<HWNativeHelper> get nativeHelpers =>
      isConstant ? const [] : const [HWNativeHelper.hwReadLocalized];

  @override
  List<HWNativeHelper> get timedNativeHelpers =>
      isConstant ? const [] : const [HWNativeHelper.hwReadTimedLocalized];

  /// A JSON leaf carries no stored locale map to merge — the decoded group is
  /// the map — so reading one resolves nothing. The exception is a preview,
  /// whose fallback is [previewTranslations] resolved as the group is decoded.
  @override
  List<HWNativeHelper> get jsonNativeHelpers =>
      isConstant || previewTranslations == null
          ? const []
          : const [
              HWNativeHelper.hwCurrentLocales,
              HWNativeHelper.hwResolveLocalized,
            ];

  /// A JSON leaf is resolved where it is displayed, out of the compiled
  /// translations alone.
  @override
  Set<HWNativeHelper> get jsonRenderHelpers => isConstant
      ? const {}
      : const {
          HWNativeHelper.hwCurrentLocales,
          HWNativeHelper.hwResolveLocalized,
        };

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final (map, base) = _kotlinCompiled(preview: preview);
    return 'hwReadLocalized($store, "$key", locales, $map, "$base")';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final (map, base) = _swiftCompiled(preview: preview);
    return 'hwReadLocalized($store, "$key", $map, baseLocale: "$base")';
  }

  /// Kotlin expression resolving this string out of the active timed entry,
  /// where [valuesExpr] is the `JSONObject` holding that entry.
  ///
  /// A time-based field carries no preferences key of its own, so the stored
  /// locale map comes from the timed data file instead. Everything after that
  /// matches [androidReadValue]: the same merge over the compiled translations
  /// and the same single resolution, so a value does not change meaning by
  /// becoming time-based.
  ///
  /// Codegen-internal; see [resourceName].
  String androidTimedReadValue({
    required String valuesExpr,
    bool preview = false,
  }) {
    final (map, base) = _kotlinCompiled(preview: preview);
    return 'hwReadTimedLocalized($valuesExpr, "$key", locales, '
        '$map, "$base")';
  }

  /// Swift counterpart of [androidTimedReadValue], where [valuesExpr] is the
  /// `[String: Any]` dictionary holding the active timed entry.
  ///
  /// Codegen-internal; see [resourceName].
  String iosTimedReadValue({
    required String valuesExpr,
    bool preview = false,
  }) {
    final (map, base) = _swiftCompiled(preview: preview);
    return 'hwReadTimedLocalized($valuesExpr, "$key", $map, '
        'baseLocale: "$base")';
  }

  /// Kotlin reading [value], a nullable text stored without its translations,
  /// with [defaultTranslations] resolved against the device's locales in its
  /// place when it is null.
  String _kotlinFallbackRead(String value) =>
      '($value ?: hwResolveLocalized(hwLocales, $kotlinMapLiteral, '
      '"${escapeKotlinStringLiteral(baseLocaleTag)}") '
      '?: "${escapeKotlinStringLiteral(baseValue)}")';

  /// Swift counterpart of [_kotlinFallbackRead].
  String _swiftFallbackRead(String value) =>
      '(($value) ?? hwResolveLocalized(hwCurrentLocales(), $swiftMapLiteral, '
      'baseLocale: "${escapeSwiftStringLiteral(baseLocaleTag)}") '
      '?? "${escapeSwiftStringLiteral(baseValue)}")';

  /// Constants read from `res/values[-<locale>]/strings.xml`.
  @override
  String kotlinAccess(String dataExpr) {
    if (!isConstant) return super.kotlinAccess(dataExpr);
    return 'context.getString(R.string.$resourceName)';
  }

  /// Constants read from the extension's `Localizable.xcstrings` catalog.
  @override
  String swiftAccess(String dataExpr) {
    if (!isConstant) return super.swiftAccess(dataExpr);
    return 'NSLocalizedString("$resourceName", comment: "")';
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    // The constant resolver already returns a non-null String; adding an elvis
    // would make Kotlin warn that the right operand is unreachable.
    if (isConstant) return outerValue;
    return super
        .androidToString(outerValue: outerValue, innerValue: innerValue);
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    if (isConstant) return outerValue;
    return super.iosToString(outerValue: outerValue, innerValue: innerValue);
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      '"${escapeKotlinStringLiteral(baseValue)}"';

  @override
  String? codegenSwiftDefaultLiteral() =>
      '"${escapeSwiftStringLiteral(baseValue)}"';

  @override
  String? codegenKotlinPreviewLiteral() {
    final value = previewBaseValue;
    return value == null ? null : '"${escapeKotlinStringLiteral(value)}"';
  }

  @override
  String? codegenSwiftPreviewLiteral() {
    final value = previewBaseValue;
    return value == null ? null : '"${escapeSwiftStringLiteral(value)}"';
  }

  /// Compatible with another declaration of the same key carrying the same
  /// [defaultTranslations]; only [previewTranslations] may be set on one side.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWLocalizedString &&
      key == other.key &&
      isConstant == other.isConstant &&
      mapEquals(defaultTranslations, other.defaultTranslations) &&
      (previewTranslations == null ||
          other.previewTranslations == null ||
          mapEquals(previewTranslations, other.previewTranslations));

  /// Keeps the receiver's [defaultLocale] and [resourcePrefix], which the
  /// parser stamps on rather than the annotation author.
  @override
  HWLocalizedString _merged(HWDataType<dynamic> other) {
    final localized = other as HWLocalizedString;
    return HWLocalizedString.resolved(
      key,
      defaultTranslations: defaultTranslations,
      isConstant: isConstant,
      defaultLocale: defaultLocale,
      previewTranslations: previewTranslations ?? localized.previewTranslations,
      resourcePrefix: resourcePrefix,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWLocalizedString &&
          key == other.key &&
          isConstant == other.isConstant &&
          defaultLocale == other.defaultLocale &&
          resourcePrefix == other.resourcePrefix &&
          mapEquals(defaultTranslations, other.defaultTranslations) &&
          mapEquals(previewTranslations, other.previewTranslations);

  @override
  int get hashCode => Object.hash(
        key,
        isConstant,
        defaultLocale,
        resourcePrefix,
        localizedContentHash(defaultTranslations),
        previewTranslations == null
            ? null
            : localizedContentHash(previewTranslations!),
      );
}

/// A data type rendered through the native number-formatting helper.
///
/// [HWInt] and [HWDouble]. Use [numberLeafOf] to find the one a data field
/// ultimately describes, whatever it is wrapped in.
sealed class HWNumericDataType<T extends num> extends HWDataType<T> {
  const HWNumericDataType(super.key);

  /// Swift expression rendering [outerValue] — the nullable access expression
  /// for this value — with [format].
  ///
  /// A missing value formats this type's own [defaultValue], and renders as
  /// empty text when there is none. [dataExpr] is the expression the data
  /// class is reached through, which a data-bound currency reads its code
  /// from.
  String iosFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) {
    final fallback = codegenSwiftDefaultLiteral();
    if (fallback != null) {
      return format.swiftCall(
        'NSNumber(value: $outerValue ?? $fallback)',
        dataExpr: dataExpr,
      );
    }
    final call = format.swiftCall(r'NSNumber(value: $0)', dataExpr: dataExpr);
    return '$outerValue.map { $call } ?? ""';
  }

  /// Kotlin counterpart of [iosFormattedValue].
  String androidFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) {
    final fallback = codegenKotlinDefaultLiteral();
    if (fallback != null) {
      return format.kotlinCall(
        '($outerValue ?: $fallback)',
        dataExpr: dataExpr,
      );
    }
    final call = format.kotlinCall('it', dataExpr: dataExpr);
    return '$outerValue?.let { $call } ?: ""';
  }

  /// A missing number renders as empty text, the same as a missing string or
  /// date; a [defaultValue] is already in place by the time a render site
  /// reads the field.
  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : ""';
  }
}

class HWInt extends HWNumericDataType<int> {
  @override
  final int? defaultValue;

  @override
  final int? previewValue;

  const HWInt(super.key, {this.defaultValue, this.previewValue});

  @override
  String get dartType => 'int';

  @override
  String get kotlinType => 'Long';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    // A Dart int is stored as an Int only while it fits 32 bits and as a Long
    // beyond that, so getInt would throw on large values.
    return 'if ($store.contains("$key")) '
        '(try { $store.getInt("$key", 0).toLong() } '
        'catch (_: ClassCastException) { $store.getLong("$key", 0L) }) '
        'else $fallback';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.object(forKey: "$key") as? Int';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}L';

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';

  @override
  String? codegenKotlinPreviewLiteral() =>
      previewValue == null ? null : '${previewValue!}L';

  @override
  String? codegenSwiftPreviewLiteral() =>
      previewValue == null ? null : '${previewValue!}';

  @override
  HWInt _merged(HWDataType<dynamic> other) {
    final number = other as HWInt;
    return HWInt(
      key,
      defaultValue: defaultValue ?? number.defaultValue,
      previewValue: previewValue ?? number.previewValue,
    );
  }
}

class HWDouble extends HWNumericDataType<double> {
  @override
  final double? defaultValue;

  @override
  final double? previewValue;

  const HWDouble(super.key, {this.defaultValue, this.previewValue});

  @override
  String get dartType => 'double';

  @override
  String get kotlinType => 'Double';

  @override
  String get swiftType => 'Double';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    return 'if ($store.contains("$key")) '
        'java.lang.Double.longBitsToDouble($store.getLong("$key", 0L)) '
        'else $fallback';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.object(forKey: "$key") as? Double';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  @override
  String? codegenKotlinDefaultLiteral() => defaultValue?.toString();

  @override
  String? codegenSwiftDefaultLiteral() => defaultValue?.toString();

  @override
  String? codegenKotlinPreviewLiteral() => previewValue?.toString();

  @override
  String? codegenSwiftPreviewLiteral() => previewValue?.toString();

  @override
  HWDouble _merged(HWDataType<dynamic> other) {
    final number = other as HWDouble;
    return HWDouble(
      key,
      defaultValue: defaultValue ?? number.defaultValue,
      previewValue: previewValue ?? number.previewValue,
    );
  }
}

class HWBool extends HWDataType<bool> {
  @override
  final bool? defaultValue;

  @override
  final bool? previewValue;

  const HWBool(super.key, {this.defaultValue, this.previewValue});

  @override
  String get dartType => 'bool';

  @override
  String get kotlinType => 'Boolean';

  @override
  String get swiftType => 'Bool';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    return 'if ($store.contains("$key")) $store.getBoolean("$key", false) else $fallback';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.object(forKey: "$key") as? Bool';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "false")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "false"';
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : '$defaultValue';

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';

  @override
  String? codegenKotlinPreviewLiteral() =>
      previewValue == null ? null : '$previewValue';

  @override
  String? codegenSwiftPreviewLiteral() =>
      previewValue == null ? null : '${previewValue!}';

  @override
  HWBool _merged(HWDataType<dynamic> other) {
    final flag = other as HWBool;
    return HWBool(
      key,
      defaultValue: defaultValue ?? flag.defaultValue,
      previewValue: previewValue ?? flag.previewValue,
    );
  }
}

/// A point in time, rendered by `HWText.dateTime`.
///
/// The app hands the generated `saveData` a Dart [DateTime]; the value travels
/// as an ISO 8601 string in UTC, and native code parses it back with the
/// generated `hwParseIsoDate` helper. Rendering always happens in the device's
/// own time zone and locale, so the same stored value follows a traveling
/// device without the app writing anything new.
///
/// There is no fixed variant and no default value: a widget with no date yet
/// renders empty text rather than a stand-in moment.
///
/// A preview instant is written as an ISO 8601 string, since [DateTime] has no
/// const constructor to put in an annotation.
class HWDateTime extends HWDataType<DateTime> {
  /// The `previewValue` argument exactly as written, unparsed.
  ///
  /// [previewValue] is this text parsed; the CLI validator rejects a spelling
  /// that does not parse.
  final String? previewIso;

  const HWDateTime(super.key, {String? previewValue})
      : previewIso = previewValue;

  @override
  DateTime? get defaultValue => null;

  /// [previewIso] parsed, or null when it is unset or not a valid ISO 8601
  /// string.
  DateTime? get previewDateTime =>
      previewIso == null ? null : DateTime.tryParse(previewIso!);

  @override
  DateTime? get previewValue => previewDateTime;

  @override
  String get dartType => 'DateTime';

  @override
  String get kotlinType => 'java.util.Date';

  @override
  String get swiftType => 'Date';

  @override
  List<HWNativeHelper> get nativeHelpers =>
      const [HWNativeHelper.hwParseIsoDate];

  /// The ISO text a read parses when nothing is stored: [previewIso] in a
  /// [preview] that has one, and the empty string — which parses to no date —
  /// otherwise.
  ///
  /// A date is read through the same parse everywhere it is stored, so the
  /// fallback is the string the app would have written rather than a native
  /// `Date` literal.
  String _isoFallback({required bool preview}) =>
      preview ? previewIso ?? '' : '';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final iso = escapeKotlinStringLiteral(_isoFallback(preview: preview));
    return 'hwParseIsoDate($store.getString("$key", null) ?: "$iso")';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final iso = escapeSwiftStringLiteral(_isoFallback(preview: preview));
    return 'hwParseIsoDate($store?.string(forKey: "$key") ?? "$iso")';
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : ""';
  }

  /// Swift expression rendering [outerValue] — the nullable `Date` access
  /// expression for this value — with [format], and as empty text when there
  /// is no date.
  ///
  /// [timeZone] decides which wall clock the instant is shown on; [dataExpr]
  /// is the expression the data class is reached through, which a data-bound
  /// zone reads its id from.
  String iosFormattedValue(
    String outerValue,
    HWDateFormat format, {
    HWTimeZone timeZone = HWTimeZone.local,
    required String dataExpr,
  }) {
    final call = format.swiftCall(
      r'$0',
      timeZone: timeZone,
      dataExpr: dataExpr,
    );
    return '$outerValue.map { $call } ?? ""';
  }

  /// Kotlin counterpart of [iosFormattedValue].
  String androidFormattedValue(
    String outerValue,
    HWDateFormat format, {
    HWTimeZone timeZone = HWTimeZone.local,
    required String dataExpr,
  }) {
    final call = format.kotlinCall(
      'it',
      timeZone: timeZone,
      dataExpr: dataExpr,
    );
    return '$outerValue?.let { $call } ?: ""';
  }

  /// Swift expression parsing this date out of [objExpr], a `[String: Any]`
  /// dictionary holding the ISO string under [key].
  ///
  /// The stored representation is a string, so the plain
  /// `values["k"] as? Date` cast the other leaf types use would always miss.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code.
  String iosJsonReadValue({
    required String objExpr,
    required String key,
    bool preview = false,
  }) {
    final iso = escapeSwiftStringLiteral(_isoFallback(preview: preview));
    return 'hwParseIsoDate(($objExpr["$key"] as? String) ?? "$iso")';
  }

  /// Kotlin counterpart of [iosJsonReadValue], where [objExpr] is a
  /// `JSONObject`.
  ///
  /// Codegen-internal; see [iosJsonReadValue].
  String androidJsonReadValue({
    required String objExpr,
    required String key,
    bool preview = false,
  }) {
    final iso = escapeKotlinStringLiteral(_isoFallback(preview: preview));
    return 'hwParseIsoDate(if ($objExpr.has("$key") && !$objExpr.isNull("$key")) '
        '$objExpr.optString("$key") else "$iso")';
  }

  /// Swift expression resolving this date out of the active timed entry, where
  /// [valuesExpr] is the `[String: Any]` dictionary holding that entry.
  ///
  /// Codegen-internal; see [iosJsonReadValue].
  String iosTimedReadValue({
    required String valuesExpr,
    bool preview = false,
  }) =>
      iosJsonReadValue(objExpr: valuesExpr, key: key, preview: preview);

  /// Kotlin counterpart of [iosTimedReadValue], where [valuesExpr] is a
  /// `JSONObject`.
  ///
  /// Codegen-internal; see [iosJsonReadValue].
  String androidTimedReadValue({
    required String valuesExpr,
    bool preview = false,
  }) =>
      androidJsonReadValue(objExpr: valuesExpr, key: key, preview: preview);

  /// Compared on [previewIso] rather than the parsed instant, so two different
  /// unparseable spellings stay in conflict instead of both reading as unset.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWDateTime &&
      key == other.key &&
      _mergeable(previewIso, other.previewIso);

  @override
  HWDateTime _merged(HWDataType<dynamic> other) => HWDateTime(
        key,
        previewValue: previewIso ?? (other as HWDateTime).previewIso,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWDateTime && key == other.key && previewIso == other.previewIso;

  @override
  int get hashCode => Object.hash(key, previewIso);
}

/// An image rendered by [HWImage].
///
/// Two const constructors:
/// - `HWImageData('avatar')` -- runtime image, the app passes an `ImageProvider`
///   to the generated `saveData(...)` helper.
/// - `HWImageData.asset('assets/logo.png')` -- bundled Flutter asset, read in
///   place from the app bundle, with nothing to save.
class HWImageData extends HWDataType<String> {
  /// The Flutter asset path for asset images, or null for runtime images.
  ///
  /// This is the raw path as declared in the owning package's pubspec, without
  /// any `packages/<package>/` prefix (see [package]).
  final String? assetPath;

  /// The package that owns [assetPath], or null for app assets and runtime
  /// images.
  ///
  /// Mirrors the `package:` parameter of Flutter's `Image.asset` /
  /// `AssetImage`.
  final String? package;

  /// The Flutter asset shown in the widget gallery while there is no runtime
  /// image, or null when the preview stays empty.
  ///
  /// Spelled like [assetPath], except that a `packages/<package>/` prefix is
  /// the only way to name a dependency's asset here.
  final String? previewAsset;

  /// An image whose bytes are supplied at runtime under [key].
  const HWImageData(super.key, {this.previewAsset})
      : assetPath = null,
        package = null;

  /// An image bundled as a Flutter asset at [path].
  ///
  /// Set [package] to load the asset from a dependency instead of the app,
  /// exactly like `Image.asset(path, package: ...)`.
  ///
  /// A [path] that already starts with `packages/` is the manual spelling of
  /// the same thing and must not be combined with [package].
  ///
  /// There is no preview asset: a bundled image previews as itself.
  const HWImageData.asset(String path, {this.package})
      : assetPath = path,
        previewAsset = null,
        super('');

  /// Whether this image is a Flutter asset read from the app bundle.
  bool get isAsset => assetPath != null;

  /// The full asset key Flutter resolves this image with, or null for runtime
  /// images.
  ///
  /// Equal to [assetPath] for app assets, and `packages/<package>/<assetPath>`
  /// when [package] is set.
  ///
  /// Throws a [GeneratorError] when [package] is set and [assetPath] already
  /// carries a `packages/` prefix, which would resolve to a doubly prefixed
  /// asset that does not exist.
  String? get effectiveAssetKey {
    final path = assetPath;
    if (path == null) return null;
    final package = this.package;
    if (package == null) return path;
    if (path.startsWith('packages/')) {
      throw GeneratorError(
        'Invalid asset "$path" with package: "$package". The path already '
        'starts with "packages/", which would resolve to '
        '"packages/$package/$path". Drop the package parameter or the '
        '"packages/" prefix.',
      );
    }
    return 'packages/$package/$path';
  }

  @override
  String get key => assetPath == null
      ? super.key
      : deriveKeyFromAssetPath(effectiveAssetKey!);

  /// Derives a deterministic, codegen-safe storage key from a Flutter
  /// [assetPath].
  ///
  /// The path is split on every run of characters outside `[A-Za-z0-9]` and the
  /// resulting segments are joined in lower camel case, e.g.
  /// `assets/images/logo.png` becomes `assetsImagesLogoPng`. Keys that would
  /// start with a digit are prefixed with `image` (`2x/logo.png` becomes
  /// `image2xLogoPng`) so the result is a valid Dart/Kotlin/Swift identifier.
  static String deriveKeyFromAssetPath(String assetPath) {
    final derived = joinIdentifierSegments(assetPath, lowerFirst: true);

    if (derived.isEmpty) {
      throw GeneratorError(
        'Cannot derive a data key from asset path "$assetPath": '
        'it contains no ASCII letters or digits.',
      );
    }

    if (RegExp('^[0-9]').hasMatch(derived)) {
      return 'image${derived[0].toUpperCase()}${derived.substring(1)}';
    }
    return derived;
  }

  /// Images never have a default value; a missing image renders nothing.
  @override
  String? get defaultValue => null;

  /// An image previews through [previewAsset], not through a stored value.
  @override
  String? get previewValue => null;

  @override
  String get dartType => 'String';

  /// An image is handed over as the picture itself, while the value stored
  /// under [key] is only the path it was written to.
  @override
  String dartApiType(String widgetClassName) => 'ImageProvider';

  /// `getData` hands back the stored path instead, since the file it names
  /// may be gone by then.
  @override
  String dartGetDataType(String widgetClassName) => dartType;

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    return '$store.getString("$key", $fallback)';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.string(forKey: "$key")';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  /// The Kotlin fallback is [previewAsset] itself: a stored image is an
  /// absolute file path, and the generated decoder reads anything else as an
  /// asset key.
  ///
  /// There is no default fallback — a runtime image with nothing saved renders
  /// nothing — and an asset image needs none, as it names its own asset.
  @override
  String? codegenKotlinFallbackLiteral({bool preview = false}) {
    final asset = preview ? previewAsset : null;
    return asset == null ? null : '"${escapeKotlinStringLiteral(asset)}"';
  }

  /// The Swift fallback is [previewAsset] itself, exactly like the Kotlin one:
  /// the decoder reads a value that is not an absolute path as an asset key on
  /// either platform.
  @override
  String? codegenSwiftFallbackLiteral({bool preview = false}) {
    final asset = preview ? previewAsset : null;
    return asset == null ? null : '"${escapeSwiftStringLiteral(asset)}"';
  }

  /// Always throws: an image path is not meaningful display text.
  ///
  /// Reachable when an image is bound to a text widget, e.g.
  /// `HWText(HWImageData('avatar'))`.
  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    throw GeneratorError(
      'HWImageData cannot be rendered as text. Use HWImage to display the '
      'image stored under "$key".',
    );
  }

  /// Always throws: an image path is not meaningful display text.
  ///
  /// Reachable when an image is bound to a text widget, e.g.
  /// `HWText(HWImageData('avatar'))`.
  @override
  String iosToString({required String outerValue, required String innerValue}) {
    throw GeneratorError(
      'HWImageData cannot be rendered as text. Use HWImage to display the '
      'image stored under "$key".',
    );
  }

  /// Compatible with another declaration of the same image — matched on
  /// [effectiveAssetKey] rather than on how the asset was spelled — that does
  /// not set a different [previewAsset].
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWImageData &&
      rawKey == other.rawKey &&
      effectiveAssetKey == other.effectiveAssetKey &&
      _mergeable(previewAsset, other.previewAsset);

  @override
  HWImageData _merged(HWDataType<dynamic> other) {
    if (isAsset) return this;
    return HWImageData(
      rawKey,
      previewAsset: previewAsset ?? (other as HWImageData).previewAsset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWImageData &&
          rawKey == other.rawKey &&
          assetPath == other.assetPath &&
          package == other.package &&
          previewAsset == other.previewAsset;

  @override
  int get hashCode => Object.hash(rawKey, assetPath, package, previewAsset);

  /// The key exactly as declared, before any derivation from [assetPath].
  ///
  /// Unlike [key] this never throws, so it is safe to use from [==] and
  /// [hashCode] on an instance whose asset spec is invalid.
  String get rawKey => super.key;
}

/// One icon of an [HWIconData], as the generated Dart enum spells it.
///
/// [name] is derived from the schema — `Icons.wb_sunny` becomes `wbSunny` — so
/// the app picks an icon by the name it wrote rather than by a codepoint;
/// [codePoint] is what actually travels to the widget.
class HWIconEntry {
  /// The lower camel case name of the generated enum value.
  final String name;

  /// The glyph this entry renders, as declared by `IconData.codePoint`.
  final int codePoint;

  /// Whether the glyph is mirrored in a right-to-left layout, as declared by
  /// `IconData.matchTextDirection`.
  ///
  /// True for the directional icons Flutter marks as such — `Icons.arrow_back`,
  /// `Icons.format_list_bulleted` — and false for everything else.
  final bool matchTextDirection;

  const HWIconEntry(
    this.name,
    this.codePoint, {
    this.matchTextDirection = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWIconEntry &&
          name == other.name &&
          codePoint == other.codePoint &&
          matchTextDirection == other.matchTextDirection;

  @override
  int get hashCode => Object.hash(name, codePoint, matchTextDirection);

  @override
  String toString() =>
      'HWIconEntry($name, 0x${codePoint.toRadixString(16).toUpperCase()})';
}

/// One of a fixed set of icons, rendered by [HWIcon].
///
/// The app picks a value out of the generated enum — `saveData(mood:
/// MoodWidgetMoodIcon.wbSunny)` — and the codepoint behind it is what is
/// stored, on both platforms, as a plain int. A widget with nothing saved and
/// no [defaultValue] renders no icon at all.
///
/// Every icon must come from the same font: the glyphs are subset out of that
/// one file and copied next to the generated widget, so a list mixing
/// `Icons.home` with a `CupertinoIcons` value is rejected.
///
/// Works inside [HWJson] and [HWTimedData] like the other value types.
///
/// The `icons` a schema writes are Flutter `IconData` constants. They are typed
/// as [Object] because this package must keep resolving without the Flutter SDK
/// — `home_widget_cli` is a plain Dart executable that depends on it — and the
/// decoder reads their `codePoint`, `fontFamily` and `fontPackage` out of the
/// analyzer constant instead, rejecting anything that carries none.
class HWIconData extends HWDataType<int> {
  /// The icons exactly as written in the annotation, in their declared order.
  ///
  /// Only ever set on the const instance living inside the annotation: the
  /// decoder reads the codepoints and names off it and hands back an instance
  /// carrying [entries] instead.
  final List<Object> icons;

  /// The icon the widget falls back to, as written in the annotation.
  final Object? defaultIcon;

  /// The icon the widget gallery shows, as written in the annotation.
  final Object? previewIcon;

  /// The icons this field may hold, name and codepoint resolved.
  ///
  /// Empty in annotation space, where [icons] is all there is.
  final List<HWIconEntry> entries;

  /// The font every one of [entries] is drawn out of, or null in annotation
  /// space.
  final HWIconFont? iconFont;

  final int? _defaultCodePoint;

  final int? _previewCodePoint;

  /// An icon chosen at runtime out of [icons].
  ///
  /// [defaultValue] and [previewValue] must be members of [icons].
  const HWIconData(
    super.key, {
    required this.icons,
    Object? defaultValue,
    Object? previewValue,
  })  : defaultIcon = defaultValue,
        previewIcon = previewValue,
        entries = const [],
        iconFont = null,
        _defaultCodePoint = null,
        _previewCodePoint = null;

  /// Rebuilt by the parser with every icon resolved to its name, codepoint and
  /// font.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code.
  const HWIconData.resolved(
    super.key, {
    required this.entries,
    required HWIconFont this.iconFont,
    int? defaultValue,
    int? previewValue,
  })  : icons = const [],
        defaultIcon = null,
        previewIcon = null,
        _defaultCodePoint = defaultValue,
        _previewCodePoint = previewValue;

  @override
  int? get defaultValue => _defaultCodePoint;

  @override
  int? get previewValue => _previewCodePoint;

  /// Every glyph this field may hold, which is what its font is subset to.
  Set<int> get codePoints => {for (final entry in entries) entry.codePoint};

  /// The glyphs of [entries] that mirror in a right-to-left layout.
  ///
  /// Empty for a field holding no directional icon.
  Set<int> get mirroredCodePoints => {
        for (final entry in entries)
          if (entry.matchTextDirection) entry.codePoint,
      };

  /// What the generated Dart enum's name ends in, e.g. `ConditionIcon` for the
  /// key `condition`.
  ///
  /// The full name is the widget's class name plus this, which only the caller
  /// knows; [enumNameFor] composes it.
  ///
  /// Codegen-internal; see [HWIconData.resolved].
  String get enumSuffix => '${joinIdentifierSegments(key)}Icon';

  /// The generated Dart enum for this field on the widget class
  /// [widgetClassName], e.g. `ForecastConditionIcon`.
  ///
  /// Codegen-internal; see [HWIconData.resolved].
  String enumNameFor(String widgetClassName) => '$widgetClassName$enumSuffix';

  /// Throws a [GeneratorError] when this field cannot be generated for.
  ///
  /// Answers for a decoded instance: that it names at least one icon, that no
  /// two of them ended up with the same enum value name or the same glyph, and
  /// that the default and preview icons are among them.
  void validate() {
    if (entries.isEmpty) {
      throw GeneratorError(
        'HWIconData "$key" needs at least one icon.',
      );
    }

    final seen = <String>{};
    final byCodePoint = <int, String>{};
    for (final entry in entries) {
      hwValidateCodePoint(
        entry.codePoint,
        'The icon "${entry.name}" of HWIconData "$key"',
      );
      if (!seen.add(entry.name)) {
        throw GeneratorError(
          'HWIconData "$key" names the icon "${entry.name}" twice. Every icon '
          'in the list becomes one value of the generated enum, so their names '
          'have to differ.',
        );
      }
      final twin = byCodePoint[entry.codePoint];
      if (twin != null) {
        throw GeneratorError(
          'The icons "$twin" and "${entry.name}" of HWIconData "$key" are the '
          'same glyph (0x${entry.codePoint.toRadixString(16).toUpperCase()}). '
          'Only the codepoint is stored, so the widget could never tell them '
          'apart — name one of them and drop the other.',
        );
      }
      byCodePoint[entry.codePoint] = entry.name;
    }

    final codePoints = this.codePoints;
    final defaultCodePoint = _defaultCodePoint;
    if (defaultCodePoint != null) {
      hwValidateCodePoint(
        defaultCodePoint,
        'The defaultValue of HWIconData "$key"',
      );
      if (!codePoints.contains(defaultCodePoint)) {
        throw GeneratorError(
          'The defaultValue of HWIconData "$key" is not one of its icons.',
        );
      }
    }
    final previewCodePoint = _previewCodePoint;
    if (previewCodePoint != null && !codePoints.contains(previewCodePoint)) {
      throw GeneratorError(
        'The previewValue of HWIconData "$key" is not one of its icons.',
      );
    }
  }

  /// The codepoint, which is what the value is stored as.
  ///
  /// The generated Dart API hands the app the enum named by [enumNameFor]
  /// instead and writes `icon.codePoint` for it.
  @override
  String get dartType => 'int';

  @override
  String dartApiType(String widgetClassName) => enumNameFor(widgetClassName);

  @override
  String dartDecode(String expr, String widgetClassName) =>
      '${enumNameFor(widgetClassName)}.fromCodePoint($expr)';

  @override
  String? dartEncode(String expr, String widgetClassName) => '$expr.codePoint';

  /// A codepoint reads as the hexadecimal literal an icon is usually written
  /// as, rather than as the decimal the storage type would print.
  @override
  String? codegenDartDefaultLiteral() {
    final value = _defaultCodePoint;
    return value == null ? null : '0x${value.toRadixString(16)}';
  }

  @override
  String get kotlinType => 'Int';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    // A codepoint always fits 32 bits, so unlike HWInt this is only ever
    // written to the store as an Int.
    return 'if ($store.contains("$key")) $store.getInt("$key", 0) '
        'else $fallback';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.object(forKey: "$key") as? Int';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  @override
  String? codegenKotlinDefaultLiteral() => _defaultCodePoint?.toString();

  @override
  String? codegenSwiftDefaultLiteral() => _defaultCodePoint?.toString();

  @override
  String? codegenKotlinPreviewLiteral() => _previewCodePoint?.toString();

  @override
  String? codegenSwiftPreviewLiteral() => _previewCodePoint?.toString();

  /// Always throws: a codepoint is not meaningful display text.
  ///
  /// Reachable when an icon is bound to a text widget, e.g.
  /// `HWText(HWIconData('mood', icons: [...]))`.
  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    throw GeneratorError(
      'HWIconData cannot be rendered as text. Use HWIcon to display the icon '
      'stored under "$key".',
    );
  }

  /// Always throws: a codepoint is not meaningful display text.
  ///
  /// Reachable when an icon is bound to a text widget, e.g.
  /// `HWText(HWIconData('mood', icons: [...]))`.
  @override
  String iosToString({required String outerValue, required String innerValue}) {
    throw GeneratorError(
      'HWIconData cannot be rendered as text. Use HWIcon to display the icon '
      'stored under "$key".',
    );
  }

  /// Compatible with another declaration of the same key offering the same
  /// icons out of the same font.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWIconData &&
      key == other.key &&
      iconFont == other.iconFont &&
      _listEquals(entries, other.entries) &&
      _listEquals(icons, other.icons) &&
      _mergeable(_defaultCodePoint, other._defaultCodePoint) &&
      _mergeable(_previewCodePoint, other._previewCodePoint);

  @override
  HWIconData _merged(HWDataType<dynamic> other) {
    final icon = other as HWIconData;
    return HWIconData.resolved(
      key,
      entries: entries,
      iconFont: iconFont!,
      defaultValue: _defaultCodePoint ?? icon._defaultCodePoint,
      previewValue: _previewCodePoint ?? icon._previewCodePoint,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWIconData &&
          key == other.key &&
          iconFont == other.iconFont &&
          _listEquals(entries, other.entries) &&
          _listEquals(icons, other.icons) &&
          _defaultCodePoint == other._defaultCodePoint &&
          _previewCodePoint == other._previewCodePoint;

  @override
  int get hashCode => Object.hash(
        key,
        iconFont,
        Object.hashAll(entries),
        Object.hashAll(icons),
        _defaultCodePoint,
        _previewCodePoint,
      );
}

/// [value] with every run of characters outside `[A-Za-z0-9]` dropped and the
/// remaining segments joined back up in camel case, e.g. `mood_of_day` becomes
/// `MoodOfDay`, or `moodOfDay` with [lowerFirst] set.
///
/// Only the first character of a segment is re-cased, so `wbSunny` survives as
/// itself. A [value] holding no ASCII letter or digit joins to the empty
/// string; every caller decides for itself what to do with that.
String joinIdentifierSegments(String value, {bool lowerFirst = false}) {
  final segments = value
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((segment) => segment.isNotEmpty)
      .toList();

  final buffer = StringBuffer();
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    buffer.write(
      i == 0 && lowerFirst
          ? segment[0].toLowerCase()
          : segment[0].toUpperCase(),
    );
    buffer.write(segment.substring(1));
  }
  return buffer.toString();
}

/// Whether [a] and [b] hold equal elements in the same order.
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A value nested in a JSON group, typed by the leaf it ends at.
///
/// `HWJson('order', HWInt('total'))` is an `HWJson<int>`, and a nested group
/// infers through to the same leaf type, so a JSON path is accepted wherever
/// the leaf's own type is — `HWText.number` takes an `HWDataType<num>` and a
/// JSON-wrapped [HWInt] satisfies it.
class HWJson<T> extends HWDataType<T> {
  /// The group member this path descends into: another [HWJson] for a nested
  /// group, otherwise the leaf itself.
  final HWDataType<T> child;

  const HWJson(super.key, this.child);

  List<String> get pathSegments {
    if (child case final HWJson<dynamic> nested) {
      return [nested.key, ...nested.pathSegments];
    }
    return [child.key];
  }

  HWDataType<dynamic> get leafType {
    if (child case final HWJson<dynamic> nested) return nested.leafType;
    return child;
  }

  @override
  HWDataType<dynamic> get leaf => leafType;

  @override
  T? get defaultValue => leafType.defaultValue as T?;

  @override
  T? get previewValue => leafType.previewValue as T?;

  @override
  String get dartType => 'Map<String, dynamic>';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  /// The leaf is reached by decoding the group, wherever the group itself was
  /// read from, so all three sites resolve to the leaf's JSON read.
  @override
  List<HWNativeHelper> get jsonNativeHelpers => child.jsonNativeHelpers;

  @override
  List<HWNativeHelper> get nativeHelpers => jsonNativeHelpers;

  @override
  List<HWNativeHelper> get timedNativeHelpers => jsonNativeHelpers;

  /// Displaying the group displays its leaf, whose value the read expression
  /// resolves out of the decoded group.
  @override
  Set<HWNativeHelper> get renderHelpers => child.jsonRenderHelpers;

  /// The group travels as one encoded string; the leaf's preview applies where
  /// that string is decoded.
  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    return '$store.getString("$key", null)';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    return '$store?.string(forKey: "$key")';
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return leafType.androidToString(
      outerValue: outerValue,
      innerValue: innerValue,
    );
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return leafType.iosToString(outerValue: outerValue, innerValue: innerValue);
  }

  @override
  String swiftAccess(String dataExpr) {
    return '$dataExpr.$key?.${pathSegments.join('?.')}';
  }

  @override
  String kotlinAccess(String dataExpr) {
    return '$dataExpr.$key?.${pathSegments.join('?.')}';
  }

  @override
  String kotlinReadExpr(String dataExpr) {
    final base = kotlinAccess(dataExpr);
    final leaf = leafType;
    if (leaf is HWLocalizedString) return leaf._kotlinFallbackRead(base);
    final literal = leaf.codegenKotlinDefaultLiteral();
    if (literal == null) return base;
    return '($base ?: $literal)';
  }

  @override
  String swiftReadExpr(String dataExpr) {
    final base = swiftAccess(dataExpr);
    final leaf = leafType;
    if (leaf is HWLocalizedString) return leaf._swiftFallbackRead(base);
    final literal = leaf.codegenSwiftDefaultLiteral();
    if (literal == null) return base;
    return '((($base) ?? ($literal)))';
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      leafType.codegenKotlinDefaultLiteral();

  @override
  String? codegenSwiftDefaultLiteral() => leafType.codegenSwiftDefaultLiteral();

  @override
  String? codegenKotlinPreviewLiteral() =>
      leafType.codegenKotlinPreviewLiteral();

  @override
  String? codegenSwiftPreviewLiteral() => leafType.codegenSwiftPreviewLiteral();

  @override
  String? codegenKotlinFallbackLiteral({bool preview = false}) =>
      leafType.codegenKotlinFallbackLiteral(preview: preview);

  @override
  String? codegenSwiftFallbackLiteral({bool preview = false}) =>
      leafType.codegenSwiftFallbackLiteral(preview: preview);

  /// Kotlin `text = ...` argument for Glance Text when bound to nested JSON data.
  String kotlinGlanceJsonTextInterpolation(String dataExpr) {
    final read = kotlinReadExpr(dataExpr);
    final leaf = leafType;
    if (leaf is HWIconData || leaf is HWImageData) {
      return leaf.androidToString(outerValue: read, innerValue: read);
    }
    // Already non-null: an elvis on top of it makes Kotlin warn.
    if (leaf is HWLocalizedString) return read;
    if (leaf.codegenKotlinDefaultLiteral() != null) {
      return leaf is HWString ? read : '$read.toString()';
    }
    return leaf.androidToString(outerValue: read, innerValue: read);
  }

  /// Swift `Text(...)` argument when bound to nested JSON data.
  String swiftGlanceJsonTextInterpolation(String dataExpr) {
    final read = swiftReadExpr(dataExpr);
    final leaf = leafType;

    if (leaf is HWIconData || leaf is HWImageData) {
      return leaf.iosToString(outerValue: read, innerValue: read);
    }

    if (leaf is HWLocalizedString) return read;

    // Keep string handling compatible with iosToString quoting rules.
    if (leaf is HWString) {
      // A leaf with a default already reads as non-optional, and Swift warns
      // on a coalesce whose left side can never be nil.
      if (leaf.codegenSwiftDefaultLiteral() != null) return read;
      return leaf.iosToString(
        outerValue: read,
        innerValue: read,
      );
    }

    // A number without a default stays optional here, and renders as empty
    // text rather than as the description of an `Optional`.
    if (leaf is HWNumericDataType &&
        leaf.codegenSwiftDefaultLiteral() == null) {
      return '($read).map { String(describing: \$0) } ?? ""';
    }

    return 'String(describing: ($read))';
  }

  /// Compatible with another path of the same key whose [child] is compatible,
  /// which for a nested group recurses down to the leaf.
  ///
  /// The leaf [defaultValue] must match exactly, since render sites inline it.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWJson &&
      key == other.key &&
      child.isCompatibleWith(other.child) &&
      leafType.defaultValue == other.leafType.defaultValue;

  @override
  HWJson<T> _merged(HWDataType<dynamic> other) {
    final json = other as HWJson<dynamic>;
    return HWJson<T>(key, child.mergedWith(json.child));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWJson &&
          key == other.key &&
          child == other.child &&
          defaultValue == other.defaultValue &&
          previewValue == other.previewValue;

  @override
  int get hashCode => Object.hash(key, child, defaultValue, previewValue);
}

/// The [HWImageData] a data field ultimately describes, or null when the field
/// is not an image.
///
/// Goes by [HWDataType.leaf], so every spelling of an image — plain,
/// time-based, inside a JSON group or a list item — answers with the same
/// [HWImageData].
HWImageData? imageLeafOf(HWDataType<dynamic> type) {
  final leaf = type.leaf;
  return leaf is HWImageData ? leaf : null;
}

/// The [HWIconData] a data field ultimately describes, or null when the field
/// is not an icon.
///
/// Descends the same wrappers as [imageLeafOf].
HWIconData? iconLeafOf(HWDataType<dynamic> type) {
  final leaf = type.leaf;
  return leaf is HWIconData ? leaf : null;
}

/// The [HWNumericDataType] a data field ultimately describes, or null when the
/// field is not a number.
///
/// Descends the same wrappers as [imageLeafOf].
HWNumericDataType<num>? numberLeafOf(HWDataType<dynamic> type) {
  final leaf = type.leaf;
  return leaf is HWNumericDataType<num> ? leaf : null;
}

/// The [HWDateTime] a data field ultimately describes, or null when the field
/// is not a date.
///
/// Descends the same wrappers as [imageLeafOf].
HWDateTime? dateTimeLeafOf(HWDataType<dynamic> type) {
  final leaf = type.leaf;
  return leaf is HWDateTime ? leaf : null;
}

/// Marks a data field as time-based.
///
/// Wraps an [HWString], [HWInt], [HWDouble], [HWBool], [HWDateTime], [HWJson]
/// or a runtime [HWImageData], and must be a root-level data field: nesting it inside
/// another [HWTimedData] or inside an [HWJson] is rejected. The asset variant
/// of [HWImageData] is rejected too — an asset ships with the app and has
/// nothing to vary over time. Several [HWTimedData] declarations may share a JSON
/// root key; they merge into a single timed root, just like untimed [HWJson]
/// declarations do.
///
/// Values for timed fields are not stored as
/// individual entries; instead they are provided through the generated
/// `saveData(timedData: ...)` parameter as a timeline of future values, stored
/// as a single JSON object. Native code resolves the value whose timestamp is
/// the latest one not after the render time. On iOS the timeline additionally
/// drives WidgetKit timeline entries; on Android it drives scheduled widget
/// updates.
class HWTimedData<T> extends HWDataType<T> {
  /// The wrapped data type whose value is resolved from the timeline.
  final HWDataType<T> data;

  const HWTimedData(this.data) : super('');

  @override
  String get key => data.key;

  @override
  T? get defaultValue => data.defaultValue;

  @override
  T? get previewValue => data.previewValue;

  @override
  String get dartType => data.dartType;

  @override
  String dartApiType(String widgetClassName) =>
      data.dartApiType(widgetClassName);

  @override
  String dartGetDataType(String widgetClassName) =>
      data.dartGetDataType(widgetClassName);

  @override
  String dartDecode(String expr, String widgetClassName) =>
      data.dartDecode(expr, widgetClassName);

  @override
  String? dartEncode(String expr, String widgetClassName) =>
      data.dartEncode(expr, widgetClassName);

  @override
  String? codegenDartDefaultLiteral() => data.codegenDartDefaultLiteral();

  @override
  String get kotlinType => data.kotlinType;

  @override
  String get swiftType => data.swiftType;

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) =>
      data.androidReadValue(store: store, key: key, preview: preview);

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) =>
      data.iosReadValue(store: store, key: key, preview: preview);

  @override
  String? codegenKotlinFallbackLiteral({bool preview = false}) =>
      data.codegenKotlinFallbackLiteral(preview: preview);

  @override
  String? codegenSwiftFallbackLiteral({bool preview = false}) =>
      data.codegenSwiftFallbackLiteral(preview: preview);

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) =>
      data.androidToString(outerValue: outerValue, innerValue: innerValue);

  @override
  String iosToString({
    required String outerValue,
    required String innerValue,
  }) =>
      data.iosToString(outerValue: outerValue, innerValue: innerValue);

  @override
  String swiftAccess(String dataExpr) => data.swiftAccess(dataExpr);

  @override
  String kotlinAccess(String dataExpr) => data.kotlinAccess(dataExpr);

  @override
  String kotlinReadExpr(String dataExpr) => data.kotlinReadExpr(dataExpr);

  @override
  String swiftReadExpr(String dataExpr) => data.swiftReadExpr(dataExpr);

  /// The value is read out of the active timed entry, never out of a
  /// preferences key of its own.
  @override
  List<HWNativeHelper> get nativeHelpers => data.timedNativeHelpers;

  /// Being time-based changes where the value is read, not how it is
  /// displayed.
  @override
  Set<HWNativeHelper> get renderHelpers => data.renderHelpers;

  @override
  HWDataType<dynamic> get unwrapped => data;

  @override
  HWDataType<dynamic> get leaf => data.leaf;

  /// Stable stand-in for the class identity in [hashCode].
  ///
  /// [operator ==] compares with `is HWTimedData` (ignoring the type argument),
  /// so `runtimeType` must not take part in the hash: `HWTimedData<String>` and
  /// `HWTimedData<dynamic>` wrapping equal data are equal and must hash equal.
  static const String _hashTag = 'HWTimedData';

  /// Compatible with another timed declaration wrapping compatible data.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWTimedData && data.isCompatibleWith(other.data);

  @override
  HWTimedData<T> _merged(HWDataType<dynamic> other) {
    final timed = other as HWTimedData<dynamic>;
    return HWTimedData<T>(data.mergedWith(timed.data));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWTimedData && data == other.data;

  @override
  int get hashCode => Object.hash(_hashTag, data);
}

/// The names the loop of an `HWColumn.builder` or `HWRow.builder` declares in
/// the generated Swift and Kotlin.
///
/// No other generated code declares them, so nothing a builder's item reads is
/// shadowed.
abstract final class HWListLoop {
  /// The item being rendered, which an [HWItemData] reads its field off.
  static const String item = 'hwItem';

  /// The position of [item] among the rendered items, counted from 0.
  static const String index = 'hwIndex';

  /// The items rendered, at most `maxItems` of them. Kotlin only.
  static const String items = 'hwItems';

  /// The baseline ascent of each of [items], which a baseline-aligned
  /// `HWRow.builder` pads its items down by. Kotlin only.
  static const String ascents = 'hwAscents';
}

/// A field of the item an `HWColumn.builder` or `HWRow.builder` renders.
///
/// `HWItemData(HWInt('temperature'))` reads `temperature` off each item of the
/// builder's list, where a plain `HWInt('temperature')` reads the widget's own
/// data, also inside an item. Only valid in the `item` of a builder.
///
/// Typed like the field it wraps, so it is accepted wherever that field is:
/// the key, the types, `defaultValue` and `previewValue` are the wrapped
/// field's, the default filling in for an item that lacks the field. Wraps an
/// [HWString] (plain or localized), [HWInt], [HWDouble], [HWBool],
/// [HWDateTime], [HWIconData] or a runtime [HWImageData]. A time-based list is
/// read through `HWTimedData(HWItemData(...))`.
class HWItemData<T> extends HWDataType<T> {
  /// The item field to read.
  final HWDataType<T> data;

  /// This field's value in each sample item the widget gallery shows, item `i`
  /// taking entry `i`, each spelled the way [data]'s own `previewValue` is.
  ///
  /// Decoded, an entry is a `String` for text, for a date's ISO 8601 text and
  /// for an image's Flutter asset path, an `int` or a `double` for a number, a
  /// `bool`, or an icon's codepoint.
  final List<Object>? previewValues;

  const HWItemData(this.data, {this.previewValues}) : super('');

  @override
  String get key => data.key;

  @override
  T? get defaultValue => data.defaultValue;

  @override
  T? get previewValue => data.previewValue;

  @override
  String get dartType => data.dartType;

  @override
  String dartApiType(String widgetClassName) =>
      data.dartApiType(widgetClassName);

  @override
  String dartGetDataType(String widgetClassName) =>
      data.dartGetDataType(widgetClassName);

  @override
  String dartDecode(String expr, String widgetClassName) =>
      data.dartDecode(expr, widgetClassName);

  @override
  String? dartEncode(String expr, String widgetClassName) =>
      data.dartEncode(expr, widgetClassName);

  @override
  String? codegenDartDefaultLiteral() => data.codegenDartDefaultLiteral();

  @override
  String get kotlinType => data.kotlinType;

  @override
  String get swiftType => data.swiftType;

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) =>
      data.androidReadValue(store: store, key: key, preview: preview);

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) =>
      data.iosReadValue(store: store, key: key, preview: preview);

  @override
  String? codegenKotlinDefaultLiteral() => data.codegenKotlinDefaultLiteral();

  @override
  String? codegenSwiftDefaultLiteral() => data.codegenSwiftDefaultLiteral();

  @override
  String? codegenKotlinPreviewLiteral() => data.codegenKotlinPreviewLiteral();

  @override
  String? codegenSwiftPreviewLiteral() => data.codegenSwiftPreviewLiteral();

  @override
  String? codegenKotlinFallbackLiteral({bool preview = false}) =>
      data.codegenKotlinFallbackLiteral(preview: preview);

  @override
  String? codegenSwiftFallbackLiteral({bool preview = false}) =>
      data.codegenSwiftFallbackLiteral(preview: preview);

  /// [data]'s, except that a localized field an item stores no text for falls
  /// back to its translations, resolved against the device's locales.
  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    final HWDataType<dynamic> field = data;
    if (field is HWLocalizedString) {
      return field._kotlinFallbackRead(outerValue);
    }
    return field.androidToString(
      outerValue: outerValue,
      innerValue: innerValue,
    );
  }

  /// Swift counterpart of [androidToString].
  @override
  String iosToString({required String outerValue, required String innerValue}) {
    final HWDataType<dynamic> field = data;
    if (field is HWLocalizedString) return field._swiftFallbackRead(outerValue);
    return field.iosToString(outerValue: outerValue, innerValue: innerValue);
  }

  /// The field off [HWListLoop.item], whatever [dataExpr] is: it stays the
  /// widget's own data for every root field read beside this one.
  @override
  String swiftAccess(String dataExpr) => '${HWListLoop.item}.$key';

  @override
  String kotlinAccess(String dataExpr) => '${HWListLoop.item}.$key';

  /// An item is read out of the decoded list the way a JSON leaf is.
  @override
  List<HWNativeHelper> get nativeHelpers => data.jsonNativeHelpers;

  @override
  List<HWNativeHelper> get timedNativeHelpers => data.jsonNativeHelpers;

  @override
  Set<HWNativeHelper> get renderHelpers => data.jsonRenderHelpers;

  @override
  HWDataType<dynamic> get leaf => data.leaf;

  /// Stable stand-in for the class identity in [hashCode], for the reason
  /// [HWTimedData] has one.
  static const String _hashTag = 'HWItemData';

  /// Compatible with another read of a compatible field whose [previewValues]
  /// agree, or are set on one side only.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) =>
      other is HWItemData &&
      data.isCompatibleWith(other.data) &&
      _listsMergeable(previewValues, other.previewValues);

  @override
  HWItemData<T> _merged(HWDataType<dynamic> other) {
    final item = other as HWItemData<dynamic>;
    return HWItemData<T>(
      data.mergedWith(item.data),
      previewValues: previewValues ?? item.previewValues,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWItemData &&
          data == other.data &&
          _optionalListEquals(previewValues, other.previewValues);

  @override
  int get hashCode {
    final values = previewValues;
    return Object.hash(
      _hashTag,
      data,
      values == null ? null : Object.hashAll(values),
    );
  }
}

/// Whether two declarations of the same optional list can be merged: they hold
/// equal elements, or only one of them sets it.
bool _listsMergeable(List<Object?>? a, List<Object?>? b) =>
    a == null || b == null || _listEquals(a, b);

/// Whether [a] and [b] are both null or hold equal elements in the same order.
bool _optionalListEquals(List<Object?>? a, List<Object?>? b) =>
    a == null || b == null ? a == b : _listEquals(a, b);
