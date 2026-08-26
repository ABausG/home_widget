import 'package:meta/meta.dart';

import 'utils/content_hash.dart';
import 'utils/map_equals.dart';
import 'utils/string_literals.dart';

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

class HWInt extends HWDataType<int> {
  @override
  final int? defaultValue;

  const HWInt(super.key, {this.defaultValue});

  @override
  String get dartType => 'int';

  @override
  String get kotlinType => 'Int';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({required String store, required String key}) {
    final fallback = defaultValue?.toString() ?? 'null';
    return 'if ($store.contains("$key")) $store.getInt("$key", 0) else $fallback';
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
    return '($outerValue?.toString() ?: "0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0"';
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : '${defaultValue!}';
}

class HWDouble extends HWDataType<double> {
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
    final fallback = defaultValue?.toString() ?? 'null';
    return 'if ($store.contains("$key")) $store.getFloat("$key", 0f).toDouble() else $fallback';
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
    return '($outerValue?.toString() ?: "0.0")';
  }

  @override
  String iosToString({required String outerValue, required String innerValue}) {
    return '$outerValue != nil ? "\\($innerValue)" : "0.0"';
  }

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

class HWJson extends HWDataType<dynamic> {
  final HWDataType<dynamic> child;

  const HWJson(super.key, this.child);

  List<String> get pathSegments {
    if (child is HWJson) {
      final nested = child as HWJson;
      return [nested.key, ...nested.pathSegments];
    }
    return [child.key];
  }

  HWDataType<dynamic> get leafType {
    if (child is HWJson) return (child as HWJson).leafType;
    return child;
  }

  @override
  dynamic get defaultValue => leafType.defaultValue;

  @override
  String get dartType => 'Map<String, dynamic>';

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
    // Already non-null: an elvis on top of it makes Kotlin warn.
    if (leafType is HWLocalizedString) return read;
    return leafType.androidToString(outerValue: read, innerValue: read);
  }

  /// Swift `Text(...)` argument when bound to nested JSON data.
  String swiftGlanceJsonTextInterpolation(String dataExpr) {
    final read = swiftReadExpr(dataExpr);
    final leaf = leafType;

    if (leaf is HWLocalizedString) return read;

    // Keep string handling compatible with iosToString quoting rules.
    if (leaf is HWString) {
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

/// Marks a data field as time-based.
///
/// Wraps any other [HWDataType]. Values for timed fields are not stored as
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
  String? codegenKotlinDefaultLiteral() => data.codegenKotlinDefaultLiteral();

  @override
  String? codegenSwiftDefaultLiteral() => data.codegenSwiftDefaultLiteral();

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

String _escapeKotlinStringLiteral(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll(r'$', r'\$').replaceAll('"', r'\"');

String _escapeSwiftStringLiteral(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
