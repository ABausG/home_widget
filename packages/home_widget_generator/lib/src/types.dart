import 'package:meta/meta.dart';

import 'formats.dart';
import 'generator_error.dart';
import 'native_helpers.dart';
import 'utils/content_hash.dart';
import 'utils/image_helper_names.dart';
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
  /// nothing, or null when this type has none.
  ///
  /// [codegenKotlinPreviewLiteral] in a [preview] that has one, and
  /// [codegenKotlinDefaultLiteral] otherwise, so one flag switches every read
  /// between the widget and the gallery.
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
  /// time-based.
  HWDataType<dynamic> get unwrapped => this;

  /// The native functions reading a stored value of this type back.
  ///
  /// Empty for the types native code reads straight out of the store; a field
  /// traveling as an encoded string names the helper decoding it, so it
  /// reaches the generated file even when nothing displays the value.
  /// Rendering helpers are named by the widget that renders, not here.
  List<HWNativeHelper> get nativeHelpers => const [];

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
  /// A missing value formats this type's own default, so the text never goes
  /// blank on a widget that has not been given data yet. [dataExpr] is the
  /// expression the data class is reached through, which a data-bound currency
  /// reads its code from.
  String iosFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  });

  /// Kotlin counterpart of [iosFormattedValue].
  String androidFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  });
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
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0"';
  }

  @override
  String iosFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.swiftCall(
        'NSNumber(value: $outerValue ?? ${defaultValue ?? 0})',
        dataExpr: dataExpr,
      );

  @override
  String androidFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.kotlinCall(
        '($outerValue ?: ${defaultValue ?? 0}L)',
        dataExpr: dataExpr,
      );

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
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return '($outerValue?.toString() ?: "0.0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0.0"';
  }

  @override
  String iosFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.swiftCall(
        'NSNumber(value: $outerValue ?? ${defaultValue ?? 0.0})',
        dataExpr: dataExpr,
      );

  @override
  String androidFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.kotlinCall(
        '($outerValue ?: ${defaultValue ?? 0.0})',
        dataExpr: dataExpr,
      );

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
  /// Named apart from [previewValue] because that one is the [DateTime] the
  /// base class types it as; this is the text it was spelled with, which the
  /// CLI validator rejects when it does not parse.
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
  /// fallback is the string the app would have written rather than the native
  /// `Date` literal [codegenKotlinPreviewLiteral] builds for a data-class field.
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

  /// The generated data class holds a `java.util.Date`, so the preview is one
  /// too rather than the ISO string it was written as.
  @override
  String? codegenKotlinPreviewLiteral() {
    final date = previewDateTime;
    return date == null
        ? null
        : 'java.util.Date(${date.millisecondsSinceEpoch}L)';
  }

  /// Swift counterpart of [codegenKotlinPreviewLiteral].
  @override
  String? codegenSwiftPreviewLiteral() {
    final date = previewDateTime;
    return date == null
        ? null
        : 'Date(timeIntervalSince1970: '
            '${date.millisecondsSinceEpoch / 1000})';
  }

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

  /// The full asset key Flutter resolves [previewAsset] with, or null when
  /// there is none.
  String? get previewAssetKey => previewAsset;

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
    final segments = assetPath
        .split(RegExp('[^A-Za-z0-9]+'))
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      throw GeneratorError(
        'Cannot derive a data key from asset path "$assetPath": '
        'it contains no ASCII letters or digits.',
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      buffer.write(
        i == 0 ? segment[0].toLowerCase() : segment[0].toUpperCase(),
      );
      buffer.write(segment.substring(1));
    }

    final derived = buffer.toString();
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

  /// The Kotlin fallback is [previewAssetKey] itself: a stored image is an
  /// absolute file path, and the generated decoder reads anything else as an
  /// asset key.
  ///
  /// There is no default fallback — a runtime image with nothing saved renders
  /// nothing — and an asset image needs none, as it names its own asset.
  @override
  String? codegenKotlinFallbackLiteral({bool preview = false}) {
    final asset = preview ? previewAssetKey : null;
    return asset == null ? null : '"${escapeKotlinStringLiteral(asset)}"';
  }

  /// The Swift fallback resolves [previewAssetKey] to an absolute bundle path,
  /// so the value reaching the decoder is the same shape a stored image has.
  @override
  String? codegenSwiftFallbackLiteral({bool preview = false}) {
    final asset = preview ? previewAssetKey : null;
    if (asset == null) return null;
    return '$swiftFlutterAssetFunction("${escapeSwiftStringLiteral(asset)}")';
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
  T? get defaultValue => leafType.defaultValue as T?;

  @override
  T? get previewValue => leafType.previewValue as T?;

  @override
  String get dartType => 'Map<String, dynamic>';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  List<HWNativeHelper> get nativeHelpers => child.nativeHelpers;

  /// The group travels as one encoded string with no fallback of its own; the
  /// leaf's preview is applied where that string is decoded.
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
    if (leaf is HWLocalizedString) {
      return '($base ?: hwResolveLocalized(hwLocales, ${leaf.kotlinMapLiteral}, '
          '"${escapeKotlinStringLiteral(leaf.baseLocaleTag)}") '
          '?: "${escapeKotlinStringLiteral(leaf.baseValue)}")';
    }
    final literal = leaf.codegenKotlinDefaultLiteral();
    if (literal == null) return base;
    return '($base ?: $literal)';
  }

  @override
  String swiftReadExpr(String dataExpr) {
    final base = swiftAccess(dataExpr);
    final leaf = leafType;
    if (leaf is HWLocalizedString) {
      return '(($base) ?? hwResolveLocalized(hwCurrentLocales(), '
          '${leaf.swiftMapLiteral}, '
          'baseLocale: "${escapeSwiftStringLiteral(leaf.baseLocaleTag)}") '
          '?? "${escapeSwiftStringLiteral(leaf.baseValue)}")';
    }
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
/// Strips an [HWTimedData] wrapper and descends an [HWJson] to its leaf, so
/// every spelling of an image — plain, time-based, inside a JSON group, or both
/// — answers with the same [HWImageData].
HWImageData? imageLeafOf(HWDataType<dynamic> type) {
  final unwrapped = type.unwrapped;
  if (unwrapped is HWImageData) return unwrapped;
  if (unwrapped is HWJson) {
    final leaf = unwrapped.leafType;
    if (leaf is HWImageData) return leaf;
  }
  return null;
}

/// The [HWNumericDataType] a data field ultimately describes, or null when the
/// field is not a number.
///
/// Strips an [HWTimedData] wrapper and descends an [HWJson] to its leaf, the
/// same way [imageLeafOf] does, so every spelling of a number answers with the
/// same [HWInt] or [HWDouble].
HWNumericDataType<num>? numberLeafOf(HWDataType<dynamic> type) {
  final unwrapped = type.unwrapped;
  if (unwrapped is HWNumericDataType<num>) return unwrapped;
  if (unwrapped is HWJson) {
    final leaf = unwrapped.leafType;
    if (leaf is HWNumericDataType<num>) return leaf;
  }
  return null;
}

/// The [HWDateTime] a data field ultimately describes, or null when the field
/// is not a date.
///
/// Descends the same wrappers as [imageLeafOf].
HWDateTime? dateTimeLeafOf(HWDataType<dynamic> type) {
  final unwrapped = type.unwrapped;
  if (unwrapped is HWDateTime) return unwrapped;
  if (unwrapped is HWJson) {
    final leaf = unwrapped.leafType;
    if (leaf is HWDateTime) return leaf;
  }
  return null;
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

  @override
  List<HWNativeHelper> get nativeHelpers => data.nativeHelpers;

  @override
  HWDataType<dynamic> get unwrapped => data;

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
