import 'native_helpers.dart';
import 'types.dart';
import 'utils/string_literals.dart';
import 'widgets/hw_generatable.dart';

/// The Kotlin expression the generated Glance code passes as the formatting
/// locale.
///
/// `context` is a parameter of the generated `WidgetContent` composable, so the
/// expression is only valid inside the widget body — which is the only place
/// formatting happens.
///
/// Codegen-internal: consumed by `home_widget_cli`, not by app code.
const String kotlinFormatLocaleExpr = 'hwFormatLocale(context)';

/// Length preset for a formatted date or time component.
enum HWFormatStyle {
  /// The shortest form, e.g. `12/31/25` / `3:30 PM`.
  short,

  /// The default form, e.g. `Dec 31, 2025` / `3:30:00 PM`.
  medium,

  /// A long form, e.g. `December 31, 2025`.
  long,

  /// The longest form, e.g. `Wednesday, December 31, 2025`.
  full;

  /// The `DateFormatter.Style` case for this style.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code.
  String get swiftStyle => '.$name';

  /// The `java.text.DateFormat` constant for this style.
  ///
  /// Codegen-internal; see [swiftStyle].
  String get kotlinStyle => 'java.text.DateFormat.${name.toUpperCase()}';
}

/// How a number is rendered by [HWText.number] and [HWText.fixedNumber].
///
/// Every variant is const, so it can live inside a `@HomeWidget(...)`
/// annotation. Formatting happens natively at render time in the device's
/// current locale, so the same widget follows a language or region change
/// without the app writing new data.
sealed class HWNumberFormat {
  const HWNumberFormat._();

  /// A plain decimal number, e.g. `1,234.5`.
  ///
  /// [minimumFractionDigits] and [maximumFractionDigits] follow the locale's
  /// own defaults when omitted; [useGrouping] toggles the thousands separator.
  const factory HWNumberFormat.decimal({
    int? minimumFractionDigits,
    int? maximumFractionDigits,
    bool useGrouping,
  }) = HWDecimalNumberFormat;

  /// A percentage, e.g. `0.5` rendered as `50%`.
  const factory HWNumberFormat.percent({
    int? minimumFractionDigits,
    int? maximumFractionDigits,
  }) = HWPercentNumberFormat;

  /// An amount of money in [currency], fixed or read from a data field.
  ///
  /// [decimalDigits] overrides the currency's own number of fraction digits.
  const factory HWNumberFormat.currency({
    required HWCurrency currency,
    int? decimalDigits,
  }) = HWCurrencyNumberFormat;

  /// A short form for large numbers, e.g. `1200` rendered as `1.2K`.
  ///
  /// On Android below API 24 there is no compact formatter, and the value
  /// renders as a plain decimal instead.
  const factory HWNumberFormat.compact() = HWCompactNumberFormat;

  /// An explicit ICU `DecimalFormat` pattern such as `#,##0.00`, with the
  /// separators and digits of the current locale.
  ///
  /// The escape hatch for raw, separator-free output: `0.###` renders
  /// `1234.5` as `1234.5` rather than `1,234.5`.
  const factory HWNumberFormat.pattern(String pattern) = HWPatternNumberFormat;

  /// The format a number renders with when none is given, and the one a plain
  /// `HWText(HWInt(...))` / `HWText(HWDouble(...))` uses.
  static const HWNumberFormat defaultFormat = HWNumberFormat.decimal();

  /// The data field this format itself reads, or null when it reads none.
  ///
  /// Only [HWNumberFormat.currency] with an [HWCurrency.data] has one; a text
  /// using this format contributes it to its data dependencies.
  HWDataType<dynamic>? get dataField => null;

  /// The native function this format is rendered by.
  ///
  /// Each variant has its own, so a widget only ever carries the formatting
  /// code it actually calls.
  HWNativeHelper get helper;

  /// The Swift call formatting [doubleExpr], a non-optional `Double`
  /// expression, where [dataExpr] is the expression the widget's data class is
  /// reached through.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code.
  String swiftCall(String doubleExpr, {required String dataExpr});

  /// The Kotlin call formatting [doubleExpr], a non-null `Double` expression.
  ///
  /// Codegen-internal; see [swiftCall].
  String kotlinCall(String doubleExpr, {required String dataExpr});
}

/// The currency an [HWNumberFormat.currency] renders in.
///
/// Either fixed at build time or read from a data field, so a widget can show
/// an amount in whichever currency the app last wrote.
sealed class HWCurrency implements HWGeneratable {
  const HWCurrency._();

  /// The currency with ISO 4217 [code], e.g. `EUR`.
  const factory HWCurrency.code(String code) = HWFixedCurrency;

  /// The currency whose ISO 4217 code is stored in [data].
  const factory HWCurrency.data(HWDataType<String> data) = HWDataCurrency;

  /// The data field supplying the code, or null when the currency is fixed.
  HWDataType<dynamic>? get dataField => null;

  /// Always empty: a currency is an argument, not a view.
  @override
  Set<String> get swiftViewModifiers => const {};

  /// Always empty: the code is a `String`, which needs no import.
  @override
  Set<String> get kotlinImports => const {};
}

/// The [HWCurrency.code] variant.
class HWFixedCurrency extends HWCurrency {
  /// The ISO 4217 code, e.g. `EUR`.
  final String code;

  /// See [HWCurrency.code].
  const HWFixedCurrency(this.code) : super._();

  @override
  String toSwift(int indent, {required String dataExpr}) =>
      '"${escapeSwiftStringLiteral(code)}"';

  @override
  String toKotlin(int indent, {required String dataExpr}) =>
      '"${escapeKotlinStringLiteral(code)}"';

  @override
  String toString() => 'HWCurrency.code($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWFixedCurrency && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// The [HWCurrency.data] variant.
class HWDataCurrency extends HWCurrency {
  /// The string field holding the ISO 4217 code.
  final HWDataType<dynamic> data;

  /// See [HWCurrency.data].
  const HWDataCurrency(this.data) : super._();

  @override
  HWDataType<dynamic>? get dataField => data;

  @override
  String toSwift(int indent, {required String dataExpr}) =>
      '${data.unwrapped.swiftAccess(dataExpr)} ?? ""';

  @override
  String toKotlin(int indent, {required String dataExpr}) =>
      '${data.unwrapped.kotlinAccess(dataExpr)} ?: ""';

  @override
  String toString() => 'HWCurrency.data(${data.key})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWDataCurrency && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// The [HWNumberFormat.decimal] variant.
class HWDecimalNumberFormat extends HWNumberFormat {
  /// The fewest fraction digits to render, or null for the locale default.
  final int? minimumFractionDigits;

  /// The most fraction digits to render, or null for the locale default.
  final int? maximumFractionDigits;

  /// Whether to group thousands with the locale's separator.
  final bool useGrouping;

  /// See [HWNumberFormat.decimal].
  const HWDecimalNumberFormat({
    this.minimumFractionDigits,
    this.maximumFractionDigits,
    this.useGrouping = true,
  }) : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatDecimal;

  @override
  String swiftCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatDecimal($doubleExpr, minFraction: '
      '${_swiftInt(minimumFractionDigits)}, maxFraction: '
      '${_swiftInt(maximumFractionDigits)}, grouping: $useGrouping)';

  @override
  String kotlinCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatDecimal($doubleExpr, ${_kotlinInt(minimumFractionDigits)}, '
      '${_kotlinInt(maximumFractionDigits)}, $useGrouping, '
      '$kotlinFormatLocaleExpr)';

  @override
  String toString() => 'HWNumberFormat.decimal(minimumFractionDigits: '
      '$minimumFractionDigits, maximumFractionDigits: '
      '$maximumFractionDigits, useGrouping: $useGrouping)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWDecimalNumberFormat &&
          minimumFractionDigits == other.minimumFractionDigits &&
          maximumFractionDigits == other.maximumFractionDigits &&
          useGrouping == other.useGrouping;

  @override
  int get hashCode => Object.hash(
        minimumFractionDigits,
        maximumFractionDigits,
        useGrouping,
      );
}

/// The [HWNumberFormat.percent] variant.
class HWPercentNumberFormat extends HWNumberFormat {
  /// The fewest fraction digits to render, or null for the locale default.
  final int? minimumFractionDigits;

  /// The most fraction digits to render, or null for the locale default.
  final int? maximumFractionDigits;

  /// See [HWNumberFormat.percent].
  const HWPercentNumberFormat({
    this.minimumFractionDigits,
    this.maximumFractionDigits,
  }) : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatPercent;

  @override
  String swiftCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatPercent($doubleExpr, minFraction: '
      '${_swiftInt(minimumFractionDigits)}, maxFraction: '
      '${_swiftInt(maximumFractionDigits)})';

  @override
  String kotlinCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatPercent($doubleExpr, ${_kotlinInt(minimumFractionDigits)}, '
      '${_kotlinInt(maximumFractionDigits)}, $kotlinFormatLocaleExpr)';

  @override
  String toString() => 'HWNumberFormat.percent(minimumFractionDigits: '
      '$minimumFractionDigits, maximumFractionDigits: '
      '$maximumFractionDigits)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWPercentNumberFormat &&
          minimumFractionDigits == other.minimumFractionDigits &&
          maximumFractionDigits == other.maximumFractionDigits;

  @override
  int get hashCode => Object.hash(minimumFractionDigits, maximumFractionDigits);
}

/// The [HWNumberFormat.currency] variant.
class HWCurrencyNumberFormat extends HWNumberFormat {
  /// The currency, fixed or data-bound.
  final HWCurrency currency;

  /// The number of fraction digits, or null for the currency's own default.
  final int? decimalDigits;

  /// See [HWNumberFormat.currency].
  const HWCurrencyNumberFormat({
    required this.currency,
    this.decimalDigits,
  }) : super._();

  @override
  HWDataType<dynamic>? get dataField => currency.dataField;

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatCurrency;

  @override
  String swiftCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatCurrency($doubleExpr, '
      'code: ${currency.toSwift(0, dataExpr: dataExpr)}, '
      'decimals: ${_swiftInt(decimalDigits)})';

  @override
  String kotlinCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatCurrency($doubleExpr, '
      '${currency.toKotlin(0, dataExpr: dataExpr)}, '
      '${_kotlinInt(decimalDigits)}, $kotlinFormatLocaleExpr)';

  @override
  String toString() => 'HWNumberFormat.currency(currency: $currency, '
      'decimalDigits: $decimalDigits)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWCurrencyNumberFormat &&
          currency == other.currency &&
          decimalDigits == other.decimalDigits;

  @override
  int get hashCode => Object.hash(currency, decimalDigits);
}

/// The [HWNumberFormat.compact] variant.
class HWCompactNumberFormat extends HWNumberFormat {
  /// See [HWNumberFormat.compact].
  const HWCompactNumberFormat() : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatCompact;

  @override
  String swiftCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatCompact($doubleExpr)';

  @override
  String kotlinCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatCompact($doubleExpr, $kotlinFormatLocaleExpr)';

  @override
  String toString() => 'HWNumberFormat.compact()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWCompactNumberFormat;

  @override
  int get hashCode => (HWCompactNumberFormat).hashCode;
}

/// The [HWNumberFormat.pattern] variant.
class HWPatternNumberFormat extends HWNumberFormat {
  /// The ICU `DecimalFormat` pattern, e.g. `#,##0.00`.
  final String pattern;

  /// See [HWNumberFormat.pattern].
  const HWPatternNumberFormat(this.pattern) : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatNumberPattern;

  @override
  String swiftCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatNumberPattern($doubleExpr, '
      '"${escapeSwiftStringLiteral(pattern)}")';

  @override
  String kotlinCall(String doubleExpr, {required String dataExpr}) =>
      'hwFormatNumberPattern($doubleExpr, '
      '"${escapeKotlinStringLiteral(pattern)}", $kotlinFormatLocaleExpr)';

  @override
  String toString() => 'HWNumberFormat.pattern($pattern)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWPatternNumberFormat && pattern == other.pattern;

  @override
  int get hashCode => pattern.hashCode;
}

/// How a date and time is rendered by [HWText.dateTime].
///
/// Every variant is const, so it can live inside a `@HomeWidget(...)`
/// annotation. Formatting happens natively at render time, in the device's
/// current locale and time zone.
sealed class HWDateFormat {
  const HWDateFormat._();

  /// An ICU skeleton such as `yMMMd`, whose field ordering and separators the
  /// locale decides.
  ///
  /// Prefer one of the named constants ([yMMMd], [jm], ...) over spelling a
  /// skeleton out.
  const factory HWDateFormat.skeleton(String skeleton) = HWSkeletonDateFormat;

  /// An explicit ICU pattern such as `dd.MM.yyyy HH:mm`, rendered the same way
  /// in every locale.
  const factory HWDateFormat.pattern(String pattern) = HWPatternDateFormat;

  /// A pair of length presets, at least one of which must be set.
  ///
  /// A null [date] renders the time only, a null [time] the date only.
  const factory HWDateFormat.styled({
    HWFormatStyle? date,
    HWFormatStyle? time,
  }) = HWStyledDateFormat;

  /// The format used when [HWText.dateTime] is given none, and by a plain
  /// `HWText(HWDateTime(...))`.
  static const HWDateFormat defaultFormat = HWDateFormat.styled(
    date: HWFormatStyle.medium,
    time: HWFormatStyle.short,
  );

  /// `9/30/2025`
  static const HWDateFormat yMd = HWDateFormat.skeleton('yMd');

  /// `Sep 30, 2025`
  static const HWDateFormat yMMMd = HWDateFormat.skeleton('yMMMd');

  /// `September 30, 2025`
  static const HWDateFormat yMMMMd = HWDateFormat.skeleton('yMMMMd');

  /// `Tue, Sep 30, 2025`
  static const HWDateFormat yMMMEd = HWDateFormat.skeleton('yMMMEd');

  /// `Tuesday, September 30, 2025`
  static const HWDateFormat yMMMMEEEEd = HWDateFormat.skeleton('yMMMMEEEEd');

  /// `9/2025`
  static const HWDateFormat yM = HWDateFormat.skeleton('yM');

  /// `Sep 2025`
  static const HWDateFormat yMMM = HWDateFormat.skeleton('yMMM');

  /// `September 2025`
  static const HWDateFormat yMMMM = HWDateFormat.skeleton('yMMMM');

  /// `Sep 30`
  // ignore: constant_identifier_names
  static const HWDateFormat MMMd = HWDateFormat.skeleton('MMMd');

  /// `Tue, Sep 30`
  // ignore: constant_identifier_names
  static const HWDateFormat MMMEd = HWDateFormat.skeleton('MMMEd');

  /// `September 30`
  // ignore: constant_identifier_names
  static const HWDateFormat MMMMd = HWDateFormat.skeleton('MMMMd');

  /// `9/30`
  // ignore: constant_identifier_names
  static const HWDateFormat Md = HWDateFormat.skeleton('Md');

  /// `Tue 30`
  // ignore: constant_identifier_names
  static const HWDateFormat Ed = HWDateFormat.skeleton('Ed');

  /// `30`
  static const HWDateFormat d = HWDateFormat.skeleton('d');

  /// `2025`
  static const HWDateFormat y = HWDateFormat.skeleton('y');

  /// `5:08 PM`, in the locale's preferred 12- or 24-hour cycle.
  static const HWDateFormat jm = HWDateFormat.skeleton('jm');

  /// `5:08:32 PM`
  static const HWDateFormat jms = HWDateFormat.skeleton('jms');

  /// `17:08`
  // ignore: constant_identifier_names
  static const HWDateFormat Hm = HWDateFormat.skeleton('Hm');

  /// `17:08:32`
  // ignore: constant_identifier_names
  static const HWDateFormat Hms = HWDateFormat.skeleton('Hms');

  /// `5 PM`
  static const HWDateFormat j = HWDateFormat.skeleton('j');

  /// `17`
  // ignore: constant_identifier_names
  static const HWDateFormat H = HWDateFormat.skeleton('H');

  /// `9/30/2025 5:08 PM`
  static const HWDateFormat yMdjm = HWDateFormat.skeleton('yMdjm');

  /// `Sep 30, 2025 5:08 PM`
  static const HWDateFormat yMMMdjm = HWDateFormat.skeleton('yMMMdjm');

  /// `September 30, 2025 5:08 PM`
  static const HWDateFormat yMMMMdjm = HWDateFormat.skeleton('yMMMMdjm');

  /// The native function this format is rendered by.
  ///
  /// Each variant has its own, so a widget only ever carries the formatting
  /// code it actually calls.
  HWNativeHelper get helper;

  /// The arguments between the date and the trailing time zone, Swift side.
  String _swiftArguments();

  /// Kotlin counterpart of [_swiftArguments], the locale argument included.
  String _kotlinArguments();

  /// The Swift call formatting [dateExpr], a non-optional `Date` expression,
  /// displayed in [timeZone].
  ///
  /// The trailing `timeZone:` argument is left off for the device's own zone,
  /// which is what the helper defaults to. [dataExpr] is the expression the
  /// widget's data class is reached through, which a data-bound zone reads its
  /// id from.
  ///
  /// Codegen-internal: consumed by `home_widget_cli`, not by app code.
  String swiftCall(
    String dateExpr, {
    HWTimeZone timeZone = HWTimeZone.local,
    required String dataExpr,
  }) {
    final zone = timeZone is HWLocalTimeZone
        ? ''
        : ', timeZone: ${timeZone.toSwift(0, dataExpr: dataExpr)}';
    return '${helper.name}($dateExpr, ${_swiftArguments()}$zone)';
  }

  /// The Kotlin call formatting [dateExpr], a non-null `java.util.Date`
  /// expression.
  ///
  /// Codegen-internal; see [swiftCall].
  String kotlinCall(
    String dateExpr, {
    HWTimeZone timeZone = HWTimeZone.local,
    required String dataExpr,
  }) {
    final zone = timeZone is HWLocalTimeZone
        ? ''
        : ', ${timeZone.toKotlin(0, dataExpr: dataExpr)}';
    return '${helper.name}($dateExpr, ${_kotlinArguments()}$zone)';
  }
}

/// The [HWDateFormat.skeleton] variant.
class HWSkeletonDateFormat extends HWDateFormat {
  /// The ICU skeleton, e.g. `yMMMd`.
  final String skeleton;

  /// See [HWDateFormat.skeleton].
  const HWSkeletonDateFormat(this.skeleton) : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatDateSkeleton;

  @override
  String _swiftArguments() => '"${escapeSwiftStringLiteral(skeleton)}"';

  @override
  String _kotlinArguments() =>
      '"${escapeKotlinStringLiteral(skeleton)}", $kotlinFormatLocaleExpr';

  @override
  String toString() => 'HWDateFormat.skeleton($skeleton)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWSkeletonDateFormat && skeleton == other.skeleton;

  @override
  int get hashCode => skeleton.hashCode;
}

/// The [HWDateFormat.pattern] variant.
class HWPatternDateFormat extends HWDateFormat {
  /// The ICU pattern, e.g. `dd.MM.yyyy HH:mm`.
  final String pattern;

  /// See [HWDateFormat.pattern].
  const HWPatternDateFormat(this.pattern) : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatDatePattern;

  @override
  String _swiftArguments() => '"${escapeSwiftStringLiteral(pattern)}"';

  @override
  String _kotlinArguments() =>
      '"${escapeKotlinStringLiteral(pattern)}", $kotlinFormatLocaleExpr';

  @override
  String toString() => 'HWDateFormat.pattern($pattern)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWPatternDateFormat && pattern == other.pattern;

  @override
  int get hashCode => pattern.hashCode;
}

/// The [HWDateFormat.styled] variant.
class HWStyledDateFormat extends HWDateFormat {
  /// The length preset for the date part, or null to omit the date.
  final HWFormatStyle? date;

  /// The length preset for the time part, or null to omit the time.
  final HWFormatStyle? time;

  /// See [HWDateFormat.styled].
  const HWStyledDateFormat({this.date, this.time}) : super._();

  @override
  HWNativeHelper get helper => HWNativeHelper.hwFormatDateStyled;

  @override
  String _swiftArguments() => 'dateStyle: ${date?.swiftStyle ?? '.none'}, '
      'timeStyle: ${time?.swiftStyle ?? '.none'}';

  @override
  String _kotlinArguments() => '${date?.kotlinStyle ?? 'null'}, '
      '${time?.kotlinStyle ?? 'null'}, $kotlinFormatLocaleExpr';

  @override
  String toString() => 'HWDateFormat.styled(date: $date, time: $time)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWStyledDateFormat && date == other.date && time == other.time;

  @override
  int get hashCode => Object.hash(date, time);
}

/// The zone a date is displayed in by `HWText.dateTime`.
///
/// The stored value is always the same instant; this only decides which wall
/// clock it is shown on. An id the device does not know falls back to the
/// device's own zone.
sealed class HWTimeZone implements HWGeneratable {
  const HWTimeZone._();

  /// The device's own time zone, and the default.
  static const HWTimeZone local = HWLocalTimeZone();

  /// UTC, whatever the device is set to.
  static const HWTimeZone utc = HWTimeZone.named('UTC');

  /// The IANA zone with [id], e.g. `Europe/Berlin`.
  const factory HWTimeZone.named(String id) = HWNamedTimeZone;

  /// The zone whose IANA id is stored in [data], an [HWString] the app writes
  /// alongside the date.
  const factory HWTimeZone.data(HWDataType<String> data) = HWDataTimeZone;

  /// The data field supplying the zone id, or null when the zone is fixed.
  ///
  /// A widget's texts contribute it to their data dependencies, so the field
  /// reaches the generated data class like any other.
  HWDataType<dynamic>? get dataField => null;

  /// The native functions resolving this zone, empty for the device's own.
  List<HWNativeHelper> get helpers => const [HWNativeHelper.hwResolveTimeZone];

  /// Always empty: a zone is an argument, not a view.
  @override
  Set<String> get swiftViewModifiers => const {};

  /// Always empty: the id is a `String`, which needs no import.
  @override
  Set<String> get kotlinImports => const {};
}

/// The [HWTimeZone.local] variant.
class HWLocalTimeZone extends HWTimeZone {
  /// See [HWTimeZone.local].
  const HWLocalTimeZone() : super._();

  @override
  List<HWNativeHelper> get helpers => const [];

  /// The device zone is what the helper falls back to, so it is spelled `nil`.
  ///
  /// The date-formatting call leaves the argument off entirely rather than
  /// passing this.
  @override
  String toSwift(int indent, {required String dataExpr}) => 'nil';

  /// Kotlin counterpart of [toSwift].
  @override
  String toKotlin(int indent, {required String dataExpr}) => 'null';

  @override
  String toString() => 'HWTimeZone.local';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWLocalTimeZone;

  @override
  int get hashCode => (HWLocalTimeZone).hashCode;
}

/// The [HWTimeZone.named] variant.
class HWNamedTimeZone extends HWTimeZone {
  /// The IANA zone id, e.g. `Europe/Berlin`.
  final String id;

  /// See [HWTimeZone.named].
  const HWNamedTimeZone(this.id) : super._();

  @override
  String toSwift(int indent, {required String dataExpr}) =>
      '"${escapeSwiftStringLiteral(id)}"';

  @override
  String toKotlin(int indent, {required String dataExpr}) =>
      '"${escapeKotlinStringLiteral(id)}"';

  @override
  String toString() => 'HWTimeZone.named($id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWNamedTimeZone && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// The [HWTimeZone.data] variant.
class HWDataTimeZone extends HWTimeZone {
  /// The string field holding the IANA zone id.
  final HWDataType<dynamic> data;

  /// See [HWTimeZone.data].
  const HWDataTimeZone(this.data) : super._();

  @override
  HWDataType<dynamic>? get dataField => data;

  @override
  String toSwift(int indent, {required String dataExpr}) =>
      data.unwrapped.swiftAccess(dataExpr);

  @override
  String toKotlin(int indent, {required String dataExpr}) =>
      data.unwrapped.kotlinAccess(dataExpr);

  @override
  String toString() => 'HWTimeZone.data(${data.key})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HWDataTimeZone && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

String _swiftInt(int? value) => value?.toString() ?? 'nil';

String _kotlinInt(int? value) => value?.toString() ?? 'null';
