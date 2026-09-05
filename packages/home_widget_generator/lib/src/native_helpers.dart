/// The native functions a generated widget calls to format its values.
///
/// Each helper is a self-contained pair of Swift and Kotlin function bodies
/// plus the helpers it calls. A widget's tree names the ones it needs
/// ([HWWidget.nativeHelpers]); `home_widget_cli` resolves that to a
/// dependency-ordered list and emits each body once per generated file.
///
/// Formatting runs at render time, in the device's locale including its region
/// — iOS `Locale.current`, Android `context.resources.configuration.locales[0]`
/// — not in the locale list the compiled translations resolve against. Dates
/// render in the device's zone unless a call passes an IANA id; an empty or
/// unknown id falls back to the device zone rather than to UTC, and an unusable
/// currency code degrades to plain decimals, so data-bound ids and codes can
/// never crash a widget or silently shift a time.
library;

import 'widgets/hw_generatable.dart';

/// A native function emitted into generated widget sources.
///
/// The Swift body goes to file scope in the generated Widget.swift, the Kotlin
/// one to a private top-level function in the generated `<Name>HomeWidget.kt`.
/// Both come out of [toSwift] / [toKotlin], which ignore their arguments: a
/// helper is the same source wherever it lands. The Kotlin bodies use short
/// type names and name what that costs in [kotlinImports], which the generator
/// merges into the file's import block alongside the widgets' own.
enum HWNativeHelper implements HWGeneratable {
  /// The locale every formatter runs in: the device's own, region included.
  ///
  /// Swift reaches `Locale` globally; the Kotlin call sites pass
  /// `hwFormatLocale(context)` because the configuration is only reachable
  /// through the composable's context.
  hwFormatLocale(
    swift: '''
func hwFormatLocale() -> Locale {
  return Locale.current
}''',
    kotlin: '''
private fun hwFormatLocale(context: Context): Locale =
    ConfigurationCompat.getLocales(context.resources.configuration)[0]
        ?: Locale.getDefault()''',
    kotlinImports: {
      'import android.content.Context',
      'import androidx.core.os.ConfigurationCompat',
      'import java.util.Locale',
    },
  ),

  /// The zone a date is displayed in, from an optional IANA id.
  ///
  /// A null, empty or unknown id is the device's own zone, so a data-bound id
  /// the device does not know shows local time rather than jumping to UTC.
  hwResolveTimeZone(
    swift: r'''
func hwResolveTimeZone(_ id: String?) -> TimeZone {
  return id.flatMap { $0.isEmpty ? nil : TimeZone(identifier: $0) } ?? TimeZone.current
}''',
    kotlin: '''
private fun hwResolveTimeZone(id: String?): TimeZone =
    if (!id.isNullOrEmpty() && TimeZone.getAvailableIDs().contains(id)) {
        TimeZone.getTimeZone(id)
    } else {
        TimeZone.getDefault()
    }''',
    kotlinImports: {'import java.util.TimeZone'},
    localeDependent: false,
  ),

  /// Parses the ISO 8601 string a date field is stored as.
  ///
  /// The generated Dart writes `toUtc().toIso8601String()` — six fractional
  /// digits and `Z` — but hand-written or older payloads may carry no fraction,
  /// one to three digits, or a `+hh:mm` offset. Both platforms normalize the
  /// fraction to the three digits their parser accepts, and treat a missing
  /// zone as UTC. Unparseable input is null, never a throw at render time.
  hwParseIsoDate(
    swift: r'''
func hwParseIsoDate(_ value: String) -> Date? {
  func normalize(_ raw: String) -> String {
    var body = raw.trimmingCharacters(in: .whitespaces)
    var zone = "Z"
    if let last = body.last, last == "Z" || last == "z" {
      body.removeLast()
    } else if let sign = body.lastIndex(where: { $0 == "+" || $0 == "-" }),
      body.distance(from: body.startIndex, to: sign) > 18
    {
      zone = String(body[sign...])
      body = String(body[body.startIndex..<sign])
    }
    var fraction = ""
    if let dot = body.firstIndex(of: ".") {
      fraction = String(body[body.index(after: dot)...]).filter { $0.isNumber }
      body = String(body[body.startIndex..<dot])
    }
    return body + "." + String((fraction + "000").prefix(3)) + zone
  }

  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.date(from: normalize(value))
}''',
    kotlin: '''
private fun hwParseIsoDate(value: String): Date? {
    fun normalize(raw: String): String {
        var body = raw.trim()
        var zone = "+0000"
        if (body.endsWith("Z", ignoreCase = true)) {
            body = body.substring(0, body.length - 1)
        } else {
            val sign = maxOf(body.lastIndexOf('+'), body.lastIndexOf('-'))
            if (sign > 18) {
                zone = body.substring(sign).replace(":", "")
                body = body.substring(0, sign)
            }
        }
        if (zone.length == 3) zone += "00"
        var fraction = ""
        val dot = body.indexOf('.')
        if (dot >= 0) {
            fraction = body.substring(dot + 1).filter { it.isDigit() }
            body = body.substring(0, dot)
        }
        return body + "." + (fraction + "000").substring(0, 3) + zone
    }

    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.US)
    formatter.timeZone = TimeZone.getTimeZone("UTC")
    formatter.isLenient = false
    return try {
        formatter.parse(normalize(value))
    } catch (_: Exception) {
        null
    }
}''',
    kotlinImports: {
      'import java.text.SimpleDateFormat',
      'import java.util.Date',
      'import java.util.Locale',
      'import java.util.TimeZone',
    },
    localeDependent: false,
  ),

  /// Renders a plain decimal number, e.g. `1,234.5`.
  ///
  /// Null fraction bounds leave the locale's own defaults in place, which is at
  /// most three fraction digits — the same as `intl`'s `decimalPattern`.
  hwFormatDecimal(
    swift: '''
func hwFormatDecimal(
  _ value: Double, minFraction: Int?, maxFraction: Int?, grouping: Bool
) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  formatter.usesGroupingSeparator = grouping
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}''',
    kotlin: '''
private fun hwFormatDecimal(
    value: Double,
    minFraction: Int?,
    maxFraction: Int?,
    grouping: Boolean,
    locale: Locale,
): String {
    val formatter = NumberFormat.getNumberInstance(locale)
    formatter.isGroupingUsed = grouping
    minFraction?.let { formatter.minimumFractionDigits = it }
    maxFraction?.let { formatter.maximumFractionDigits = it }
    return formatter.format(value)
}''',
    kotlinImports: {
      'import java.text.NumberFormat',
      'import java.util.Locale',
    },
    dependencies: [HWNativeHelper.hwFormatLocale],
  ),

  /// Renders a fraction as a percentage: `0.5` becomes `50%`.
  hwFormatPercent(
    swift: '''
func hwFormatPercent(_ value: Double, minFraction: Int?, maxFraction: Int?) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .percent
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}''',
    kotlin: '''
private fun hwFormatPercent(
    value: Double,
    minFraction: Int?,
    maxFraction: Int?,
    locale: Locale,
): String {
    val formatter = NumberFormat.getPercentInstance(locale)
    minFraction?.let { formatter.minimumFractionDigits = it }
    maxFraction?.let { formatter.maximumFractionDigits = it }
    return formatter.format(value)
}''',
    kotlinImports: {
      'import java.text.NumberFormat',
      'import java.util.Locale',
    },
    dependencies: [HWNativeHelper.hwFormatLocale],
  ),

  /// Renders an amount of money in the ISO 4217 currency `code`.
  ///
  /// The code can come from widget data, so an empty or unknown one falls back
  /// to plain decimals instead of throwing. Swift checks it against the
  /// system's currency list on iOS 16 and up — `Locale.isoCurrencyCodes` is
  /// deprecated there, and generated code must build without warnings — and
  /// against its shape on iOS 15.
  ///
  /// `NumberFormatter` re-derives its fraction digits from `currencyCode`, but
  /// `DecimalFormat.setCurrency` leaves the locale's own in place, so the Kotlin
  /// side applies the currency's `defaultFractionDigits` itself — otherwise a
  /// zero-digit currency like JPY renders as `¥1,234.50` on Android alone. A
  /// negative default is what pseudo-currencies such as XXX report; those keep
  /// the formatter's own digits.
  hwFormatCurrency(
    swift: r'''
func hwFormatCurrency(_ value: Double, code: String, decimals: Int?) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  let isoCode = code.uppercased()
  let isCode: Bool
  if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
    isCode = Locale.Currency.isoCurrencies.contains { $0.identifier.uppercased() == isoCode }
  } else {
    isCode = isoCode.count == 3 && isoCode.allSatisfy { $0.isLetter }
  }
  formatter.numberStyle = isCode ? .currency : .decimal
  if isCode { formatter.currencyCode = isoCode }
  if let decimals {
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
  }
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}''',
    kotlin: '''
private fun hwFormatCurrency(
    value: Double,
    code: String,
    decimals: Int?,
    locale: Locale,
): String {
    val resolved =
        try {
            Currency.getInstance(code.uppercase(Locale.ROOT))
        } catch (_: IllegalArgumentException) {
            null
        }
    val formatter =
        if (resolved == null) {
            NumberFormat.getNumberInstance(locale)
        } else {
            NumberFormat.getCurrencyInstance(locale).apply {
                currency = resolved
                val defaults = resolved.defaultFractionDigits
                if (decimals == null && defaults >= 0) {
                    minimumFractionDigits = defaults
                    maximumFractionDigits = defaults
                }
            }
        }
    decimals?.let {
        formatter.minimumFractionDigits = it
        formatter.maximumFractionDigits = it
    }
    return formatter.format(value)
}''',
    kotlinImports: {
      'import java.text.NumberFormat',
      'import java.util.Currency',
      'import java.util.Locale',
    },
    dependencies: [HWNativeHelper.hwFormatLocale],
  ),

  /// Renders a large number in short form: `1200` becomes `1.2K`.
  ///
  /// Both platforms gained a compact formatter one version after the oldest one
  /// generated widgets run on — iOS 15, Android API 24 — so below that the value
  /// renders as a plain decimal rather than not at all.
  hwFormatCompact(
    swift: '''
func hwFormatCompact(_ value: Double) -> String {
  if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
    return value.formatted(.number.notation(.compactName).locale(hwFormatLocale()))
  }
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}''',
    kotlin: '''
private fun hwFormatCompact(value: Double, locale: Locale): String {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        val compact =
            CompactDecimalFormat.getInstance(
                locale,
                CompactDecimalFormat.CompactStyle.SHORT,
            )
        return compact.format(value)
    }
    return NumberFormat.getNumberInstance(locale).format(value)
}''',
    kotlinImports: {
      'import android.icu.text.CompactDecimalFormat',
      'import android.os.Build',
      'import java.text.NumberFormat',
      'import java.util.Locale',
    },
    dependencies: [HWNativeHelper.hwFormatLocale],
  ),

  /// Renders a number with an explicit ICU `DecimalFormat` pattern such as
  /// `#,##0.00`, in the locale's own digits and separators.
  ///
  /// `NumberFormatter` has no pattern property that covers negatives, so the
  /// Swift side splits the ICU sub-patterns itself. `DecimalFormat` rejects a
  /// malformed pattern outright, so the Kotlin side falls back to the locale's
  /// own decimal format rather than letting the whole widget fail to load.
  hwFormatNumberPattern(
    swift: '''
func hwFormatNumberPattern(_ value: Double, _ pattern: String) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  let parts = pattern.components(separatedBy: ";")
  let positive = parts.first ?? pattern
  formatter.positiveFormat = positive
  formatter.negativeFormat = parts.count > 1 ? parts[1] : "-" + positive
  return formatter.string(from: NSNumber(value: value)) ?? String(value)
}''',
    kotlin: '''
private fun hwFormatNumberPattern(
    value: Double,
    pattern: String,
    locale: Locale,
): String {
    val formatter =
        try {
            DecimalFormat(pattern, DecimalFormatSymbols.getInstance(locale))
        } catch (_: IllegalArgumentException) {
            NumberFormat.getNumberInstance(locale)
        }
    return formatter.format(value)
}''',
    kotlinImports: {
      'import java.text.DecimalFormat',
      'import java.text.DecimalFormatSymbols',
      'import java.text.NumberFormat',
      'import java.util.Locale',
    },
    dependencies: [HWNativeHelper.hwFormatLocale],
  ),

  /// Renders a date from an ICU skeleton such as `yMMMd`, whose field ordering
  /// and separators the locale decides.
  ///
  /// Android's skeleton resolver is `android.text.format.DateFormat`, which
  /// shares its short name with the `java.text.DateFormat` the styled helper
  /// needs, so this one imports it under an alias.
  hwFormatDateSkeleton(
    swift: '''
func hwFormatDateSkeleton(_ date: Date, _ skeleton: String, timeZone: String? = nil) -> String {
  let locale = hwFormatLocale()
  let formatter = DateFormatter()
  formatter.locale = locale
  formatter.timeZone = hwResolveTimeZone(timeZone)
  formatter.dateFormat =
    DateFormatter.dateFormat(fromTemplate: skeleton, options: 0, locale: locale) ?? skeleton
  return formatter.string(from: date)
}''',
    kotlin: '''
private fun hwFormatDateSkeleton(
    date: Date,
    skeleton: String,
    locale: Locale,
    timeZoneId: String? = null,
): String {
    val pattern = AndroidDateFormat.getBestDateTimePattern(locale, skeleton)
    val formatter = SimpleDateFormat(pattern, locale)
    formatter.timeZone = hwResolveTimeZone(timeZoneId)
    return formatter.format(date)
}''',
    kotlinImports: {
      'import android.text.format.DateFormat as AndroidDateFormat',
      'import java.text.SimpleDateFormat',
      'import java.util.Date',
      'import java.util.Locale',
    },
    dependencies: [
      HWNativeHelper.hwFormatLocale,
      HWNativeHelper.hwResolveTimeZone,
    ],
  ),

  /// Renders a date with an explicit ICU pattern such as `dd.MM.yyyy HH:mm`,
  /// which comes out the same way in every locale.
  ///
  /// `SimpleDateFormat` rejects a malformed pattern outright, so the Kotlin side
  /// falls back to the locale's default date and time rather than letting the
  /// whole widget fail to load.
  hwFormatDatePattern(
    swift: '''
func hwFormatDatePattern(_ date: Date, _ pattern: String, timeZone: String? = nil) -> String {
  let formatter = DateFormatter()
  formatter.locale = hwFormatLocale()
  formatter.timeZone = hwResolveTimeZone(timeZone)
  formatter.dateFormat = pattern
  return formatter.string(from: date)
}''',
    kotlin: '''
private fun hwFormatDatePattern(
    date: Date,
    pattern: String,
    locale: Locale,
    timeZoneId: String? = null,
): String {
    val formatter =
        try {
            SimpleDateFormat(pattern, locale)
        } catch (_: IllegalArgumentException) {
            DateFormat.getDateTimeInstance(
                DateFormat.MEDIUM,
                DateFormat.SHORT,
                locale,
            )
        }
    formatter.timeZone = hwResolveTimeZone(timeZoneId)
    return formatter.format(date)
}''',
    kotlinImports: {
      'import java.text.DateFormat',
      'import java.text.SimpleDateFormat',
      'import java.util.Date',
      'import java.util.Locale',
    },
    dependencies: [
      HWNativeHelper.hwFormatLocale,
      HWNativeHelper.hwResolveTimeZone,
    ],
  ),

  /// Renders a date from a pair of length presets, either of which may be
  /// absent to leave that part out.
  ///
  /// Swift takes `DateFormatter.Style` (`.none` for an absent part), Kotlin the
  /// `java.text.DateFormat` constants with null for absent — no custom enum on
  /// either side.
  hwFormatDateStyled(
    swift: '''
func hwFormatDateStyled(
  _ date: Date,
  dateStyle: DateFormatter.Style,
  timeStyle: DateFormatter.Style,
  timeZone: String? = nil
) -> String {
  let formatter = DateFormatter()
  formatter.locale = hwFormatLocale()
  formatter.timeZone = hwResolveTimeZone(timeZone)
  formatter.dateStyle = dateStyle
  formatter.timeStyle = timeStyle
  return formatter.string(from: date)
}''',
    kotlin: '''
private fun hwFormatDateStyled(
    date: Date,
    dateStyle: Int?,
    timeStyle: Int?,
    locale: Locale,
    timeZoneId: String? = null,
): String {
    val formatter =
        when {
            dateStyle != null && timeStyle != null ->
                DateFormat.getDateTimeInstance(dateStyle, timeStyle, locale)
            dateStyle != null -> DateFormat.getDateInstance(dateStyle, locale)
            timeStyle != null -> DateFormat.getTimeInstance(timeStyle, locale)
            else ->
                DateFormat.getDateTimeInstance(
                    DateFormat.MEDIUM,
                    DateFormat.SHORT,
                    locale,
                )
        }
    formatter.timeZone = hwResolveTimeZone(timeZoneId)
    return formatter.format(date)
}''',
    kotlinImports: {
      'import java.text.DateFormat',
      'import java.util.Date',
      'import java.util.Locale',
    },
    dependencies: [
      HWNativeHelper.hwFormatLocale,
      HWNativeHelper.hwResolveTimeZone,
    ],
  );

  const HWNativeHelper({
    required String swift,
    required String kotlin,
    this.kotlinImports = const {},
    this.dependencies = const [],
    this.localeDependent = true,
  })  : _swift = swift,
        _kotlin = kotlin;

  final String _swift;

  final String _kotlin;

  /// The imports the Kotlin body's short type names stand for.
  @override
  final Set<String> kotlinImports;

  /// The helpers these bodies call, which have to be emitted alongside them.
  final List<HWNativeHelper> dependencies;

  /// Whether what this helper produces changes with the device locale.
  ///
  /// A widget that uses one of these goes stale when the user switches language
  /// or region, so Android has to listen for `LOCALE_CHANGED` even if the widget
  /// shows no translated text. Reading a stored value back — parsing a date,
  /// resolving a zone id — does not depend on the locale. The default is `true`
  /// so a helper added later over-refreshes rather than showing stale text.
  final bool localeDependent;

  /// Always empty: a helper is a function, not a view.
  @override
  Set<String> get swiftViewModifiers => const {};

  /// The Swift body, verbatim; both arguments are ignored.
  @override
  String toSwift(int indent, {required String dataExpr}) => _swift;

  /// The Kotlin body, verbatim; both arguments are ignored.
  @override
  String toKotlin(int indent, {required String dataExpr}) => _kotlin;
}
