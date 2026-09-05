import 'package:meta/meta.dart';

import 'formats.dart';
import 'generator_error.dart';
import 'native_helpers.dart';
import 'utils/content_hash.dart';
import 'utils/map_equals.dart';
import 'utils/string_literals.dart';

const HWNumberFormat _defaultNumberFormat = HWNumberFormat.defaultFormat;

/// Base class for all data type descriptors used in @HomeWidget(data: {...}).
sealed class HWDataType<T> {
  final String key;
  const HWDataType(this.key);

  /// The default value.
  T? get defaultValue;

  /// The Dart type string.
  String get dartType;

  /// The Kotlin type string.
  String get kotlinType;

  /// The Swift type string.
  String get swiftType;

  /// Returns the Kotlin code to read this value from SharedPreferences.
  /// [store] is the variable name of the SharedPreferences instance (e.g. "prefs").
  /// [key] is the full key string (e.g. "${PREFERENCES_PREFIX}.count").
  String androidReadValue({required String store, required String key});

  /// Returns the Swift code to read this value from UserDefaults.
  /// [store] is the variable name of the UserDefaults instance (e.g. "defaults").
  /// [key] is the full key string.
  String iosReadValue({required String store, required String key});

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWDataType &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(key, defaultValue);
}

class HWString extends HWDataType<String> {
  @override
  final String? defaultValue;

  const HWString(super.key, {this.defaultValue});

  /// A string whose shipped value differs per locale, and which can additionally
  /// be overridden per locale at runtime via the generated `saveData`.
  ///
  /// [defaultTranslations] maps locale tag to text and must include the
  /// widget's `defaultLocale`. At render time each of the user's preferred
  /// languages is tried in order — exact tag (`pt-PT`), then language (`pt`),
  /// then any key sharing that language with a different region or script
  /// (`pt-BR`) — before falling back to the default locale.
  ///
  /// A const factory, so it is usable inside a `@HomeWidget(...)` annotation.
  const factory HWString.localized(
    String key, {
    required Map<String, String> defaultTranslations,
  }) = HWLocalizedString;

  @override
  String get dartType => 'String';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue != null
        ? '"${escapeKotlinStringLiteral(defaultValue!)}"'
        : 'null';
    return '$store.getString("$key", $fallback)';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.string(forKey: "$key")';
    if (defaultValue != null) {
      return '($read ?? "${escapeSwiftStringLiteral(defaultValue!)}")';
    }
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
  String get baseLocaleTag {
    final locale = defaultLocale;
    if (locale != null && defaultTranslations.containsKey(locale)) {
      return locale;
    }
    return defaultTranslations.keys.isEmpty
        ? ''
        : defaultTranslations.keys.first;
  }

  /// The base-locale text.
  ///
  /// Codegen-internal; see [resourceName].
  String get baseValue => defaultTranslations[baseLocaleTag] ?? '';

  /// `mapOf("en" to "Hello", "de" to "Hallo")`
  @internal
  String get kotlinMapLiteral {
    if (defaultTranslations.isEmpty) return 'emptyMap()';
    final entries = defaultTranslations.entries
        .map(
          (e) => '"${escapeKotlinStringLiteral(e.key)}" to '
              '"${escapeKotlinStringLiteral(e.value)}"',
        )
        .join(', ');
    return 'mapOf($entries)';
  }

  /// `["en": "Hello", "de": "Hallo"]`
  @internal
  String get swiftMapLiteral {
    if (defaultTranslations.isEmpty) return '[:]';
    final entries = defaultTranslations.entries
        .map(
          (e) => '"${escapeSwiftStringLiteral(e.key)}": '
              '"${escapeSwiftStringLiteral(e.value)}"',
        )
        .join(', ');
    return '[$entries]';
  }

  @override
  String androidReadValue({required String store, required String key}) {
    return 'hwReadLocalized($store, "$key", locales, $kotlinMapLiteral, '
        '"${escapeKotlinStringLiteral(baseLocaleTag)}")';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return 'hwReadLocalized($store, "$key", $swiftMapLiteral, '
        'baseLocale: "${escapeSwiftStringLiteral(baseLocaleTag)}")';
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
  String androidTimedReadValue({required String valuesExpr}) {
    return 'hwReadTimedLocalized($valuesExpr, "$key", locales, '
        '$kotlinMapLiteral, "${escapeKotlinStringLiteral(baseLocaleTag)}")';
  }

  /// Swift counterpart of [androidTimedReadValue], where [valuesExpr] is the
  /// `[String: Any]` dictionary holding the active timed entry.
  ///
  /// Codegen-internal; see [resourceName].
  String iosTimedReadValue({required String valuesExpr}) {
    return 'hwReadTimedLocalized($valuesExpr, "$key", $swiftMapLiteral, '
        'baseLocale: "${escapeSwiftStringLiteral(baseLocaleTag)}")';
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWLocalizedString &&
          key == other.key &&
          isConstant == other.isConstant &&
          defaultLocale == other.defaultLocale &&
          resourcePrefix == other.resourcePrefix &&
          mapEquals(defaultTranslations, other.defaultTranslations);

  @override
  int get hashCode => Object.hash(
        key,
        isConstant,
        defaultLocale,
        resourcePrefix,
        localizedContentHash(defaultTranslations),
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

  const HWInt(super.key, {this.defaultValue});

  @override
  String get dartType => 'int';

  @override
  String get kotlinType => 'Long';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = codegenKotlinDefaultLiteral() ?? 'null';
    // A Dart int is stored as an Int only while it fits 32 bits and as a Long
    // beyond that, so getInt would throw on large values.
    return 'when (val raw = $store.all["$key"]) { '
        'is Int -> raw.toLong(); '
        'is Long -> raw; '
        'else -> $fallback }';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.object(forKey: "$key") as? Int';
    if (defaultValue != null) return '($read ?? $defaultValue)';
    return read;
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return androidFormattedValue(
      outerValue,
      _defaultNumberFormat,
      dataExpr: '',
    );
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return iosFormattedValue(outerValue, _defaultNumberFormat, dataExpr: '');
  }

  @override
  String iosFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.swiftCall(
        'Double($outerValue ?? ${defaultValue ?? 0})',
        dataExpr: dataExpr,
      );

  @override
  String androidFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.kotlinCall(
        '($outerValue ?: ${defaultValue ?? 0}L).toDouble()',
        dataExpr: dataExpr,
      );

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}L';

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';
}

class HWDouble extends HWNumericDataType<double> {
  @override
  final double? defaultValue;

  const HWDouble(super.key, {this.defaultValue});

  @override
  String get dartType => 'double';

  @override
  String get kotlinType => 'Double';

  @override
  String get swiftType => 'Double';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = codegenKotlinDefaultLiteral() ?? 'null';
    return 'if ($store.contains("$key")) '
        'java.lang.Double.longBitsToDouble($store.getLong("$key", 0L)) '
        'else $fallback';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.object(forKey: "$key") as? Double';
    if (defaultValue != null) return '($read ?? $defaultValue)';
    return read;
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return androidFormattedValue(
      outerValue,
      _defaultNumberFormat,
      dataExpr: '',
    );
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return iosFormattedValue(outerValue, _defaultNumberFormat, dataExpr: '');
  }

  @override
  String iosFormattedValue(
    String outerValue,
    HWNumberFormat format, {
    required String dataExpr,
  }) =>
      format.swiftCall(
        '$outerValue ?? ${defaultValue ?? 0.0}',
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
}

class HWBool extends HWDataType<bool> {
  @override
  final bool? defaultValue;

  const HWBool(super.key, {this.defaultValue});

  @override
  String get dartType => 'bool';

  @override
  String get kotlinType => 'Boolean';

  @override
  String get swiftType => 'Bool';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue?.toString() ?? 'null';
    return 'if ($store.contains("$key")) $store.getBoolean("$key", false) else $fallback';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    final read = '$store?.object(forKey: "$key") as? Bool';
    if (defaultValue != null) return '($read ?? $defaultValue)';
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
class HWDateTime extends HWDataType<DateTime> {
  const HWDateTime(super.key);

  @override
  DateTime? get defaultValue => null;

  @override
  String get dartType => 'DateTime';

  @override
  String get kotlinType => 'java.util.Date';

  @override
  String get swiftType => 'Date';

  @override
  List<HWNativeHelper> get nativeHelpers =>
      const [HWNativeHelper.hwParseIsoDate];

  @override
  String androidReadValue({required String store, required String key}) {
    return 'hwParseIsoDate($store.getString("$key", null) ?: "")';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return 'hwParseIsoDate($store?.string(forKey: "$key") ?? "")';
  }

  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) {
    return androidFormattedValue(
      outerValue,
      HWDateFormat.defaultFormat,
      dataExpr: '',
    );
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return iosFormattedValue(
      outerValue,
      HWDateFormat.defaultFormat,
      dataExpr: '',
    );
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
  String iosJsonReadValue({required String objExpr, required String key}) =>
      'hwParseIsoDate(($objExpr["$key"] as? String) ?? "")';

  /// Kotlin counterpart of [iosJsonReadValue], where [objExpr] is a
  /// `JSONObject`.
  ///
  /// Codegen-internal; see [iosJsonReadValue].
  String androidJsonReadValue({
    required String objExpr,
    required String key,
  }) =>
      'hwParseIsoDate(if ($objExpr.has("$key") && !$objExpr.isNull("$key")) '
      '$objExpr.optString("$key") else "")';

  /// Swift expression resolving this date out of the active timed entry, where
  /// [valuesExpr] is the `[String: Any]` dictionary holding that entry.
  ///
  /// Codegen-internal; see [iosJsonReadValue].
  String iosTimedReadValue({required String valuesExpr}) =>
      iosJsonReadValue(objExpr: valuesExpr, key: key);

  /// Kotlin counterpart of [iosTimedReadValue], where [valuesExpr] is a
  /// `JSONObject`.
  ///
  /// Codegen-internal; see [iosJsonReadValue].
  String androidTimedReadValue({required String valuesExpr}) =>
      androidJsonReadValue(objExpr: valuesExpr, key: key);
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

  /// An image whose bytes are supplied at runtime under [key].
  const HWImageData(super.key)
      : assetPath = null,
        package = null;

  /// An image bundled as a Flutter asset at [path].
  ///
  /// Set [package] to load the asset from a dependency instead of the app,
  /// exactly like `Image.asset(path, package: ...)`.
  ///
  /// A [path] that already starts with `packages/` is the manual spelling of
  /// the same thing and must not be combined with [package].
  const HWImageData.asset(String path, {this.package})
      : assetPath = path,
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

  @override
  String get dartType => 'String';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  String androidReadValue({required String store, required String key}) {
    return '$store.getString("$key", null)';
  }

  @override
  String iosReadValue({required String store, required String key}) {
    return '$store?.string(forKey: "$key")';
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWImageData &&
          rawKey == other.rawKey &&
          assetPath == other.assetPath &&
          package == other.package;

  @override
  int get hashCode => Object.hash(rawKey, assetPath, package);

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
  String get dartType => 'Map<String, dynamic>';

  @override
  String get kotlinType => 'String';

  @override
  String get swiftType => 'String';

  @override
  List<HWNativeHelper> get nativeHelpers => child.nativeHelpers;

  @override
  String androidReadValue({required String store, required String key}) {
    return '$store.getString("$key", null)';
  }

  @override
  String iosReadValue({required String store, required String key}) {
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

  /// Kotlin `text = ...` argument for Glance Text when bound to nested JSON data.
  String kotlinGlanceJsonTextInterpolation(String dataExpr) {
    final read = kotlinReadExpr(dataExpr);
    final leaf = leafType;
    // Already non-null: an elvis on top of it makes Kotlin warn.
    if (leaf is HWLocalizedString) return read;
    // Formatted leaves apply the leaf default themselves, on the raw path.
    if (leaf is HWNumericDataType<num>) {
      return leaf.androidFormattedValue(
        kotlinAccess(dataExpr),
        _defaultNumberFormat,
        dataExpr: dataExpr,
      );
    }
    if (leaf is HWDateTime) {
      return leaf.androidFormattedValue(
        kotlinAccess(dataExpr),
        HWDateFormat.defaultFormat,
        dataExpr: dataExpr,
      );
    }
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

    // Formatted leaves apply the leaf default themselves, on the raw path.
    if (leaf is HWNumericDataType<num>) {
      return leaf.iosFormattedValue(
        swiftAccess(dataExpr),
        _defaultNumberFormat,
        dataExpr: dataExpr,
      );
    }
    if (leaf is HWDateTime) {
      return leaf.iosFormattedValue(
        swiftAccess(dataExpr),
        HWDateFormat.defaultFormat,
        dataExpr: dataExpr,
      );
    }

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWJson &&
          key == other.key &&
          child == other.child &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(key, child, defaultValue);
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
  String get dartType => data.dartType;

  @override
  String get kotlinType => data.kotlinType;

  @override
  String get swiftType => data.swiftType;

  @override
  String androidReadValue({required String store, required String key}) =>
      data.androidReadValue(store: store, key: key);

  @override
  String iosReadValue({required String store, required String key}) =>
      data.iosReadValue(store: store, key: key);

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWTimedData && data == other.data;

  @override
  int get hashCode => Object.hash(_hashTag, data);
}
