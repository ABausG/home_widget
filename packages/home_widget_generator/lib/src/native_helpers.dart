/// The native functions a generated widget calls to read, resolve, format and
/// render its values.
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
/// helper is the same source wherever it lands. The bodies use short type
/// names and name what that costs in [kotlinImports] / [swiftImports], which
/// the generator merges into the file's import block alongside the widgets'
/// own.
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
private fun hwResolveTimeZone(id: String?): TimeZone {
    if (id.isNullOrEmpty()) return TimeZone.getDefault()
    val normalized = id.replace(Regex("^(UTC|UT)(?=[+-])"), "GMT")
    val zone = TimeZone.getTimeZone(normalized)
    val unknown = zone.id == "GMT" && !normalized.equals("GMT", ignoreCase = true)
    return if (unknown) TimeZone.getDefault() else zone
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
  _ value: NSNumber, minFraction: Int?, maxFraction: Int?, grouping: Bool
) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  formatter.usesGroupingSeparator = grouping
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: value) ?? value.stringValue
}''',
    kotlin: '''
private fun hwFormatDecimal(
    value: Number,
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
func hwFormatPercent(_ value: NSNumber, minFraction: Int?, maxFraction: Int?) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .percent
  if let minFraction { formatter.minimumFractionDigits = minFraction }
  if let maxFraction { formatter.maximumFractionDigits = maxFraction }
  return formatter.string(from: value) ?? value.stringValue
}''',
    kotlin: '''
private fun hwFormatPercent(
    value: Number,
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
func hwFormatCurrency(_ value: NSNumber, code: String, decimals: Int?) -> String {
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
  return formatter.string(from: value) ?? value.stringValue
}''',
    kotlin: '''
private fun hwFormatCurrency(
    value: Number,
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
                if (defaults >= 0) {
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
func hwFormatCompact(_ value: NSNumber) -> String {
  if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
    return value.doubleValue.formatted(.number.notation(.compactName).locale(hwFormatLocale()))
  }
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  formatter.numberStyle = .decimal
  return formatter.string(from: value) ?? value.stringValue
}''',
    kotlin: '''
private fun hwFormatCompact(value: Number, locale: Locale): String {
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
func hwFormatNumberPattern(_ value: NSNumber, _ pattern: String) -> String {
  let formatter = NumberFormatter()
  formatter.locale = hwFormatLocale()
  let parts = pattern.components(separatedBy: ";")
  let positive = parts.first ?? pattern
  formatter.positiveFormat = positive
  formatter.negativeFormat = parts.count > 1 ? parts[1] : "-" + positive
  return formatter.string(from: value) ?? value.stringValue
}''',
    kotlin: '''
private fun hwFormatNumberPattern(
    value: Number,
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
  ),

  /// The user's preferred languages, most-wanted first, as BCP 47 tags.
  ///
  /// Android reads the tags through `toLanguageTag()` rather than
  /// `getLanguage()`, which still returns the obsolete ISO 639 codes (iw, in,
  /// ji) and drops the script subtag — a `zh-Hant` device would arrive as
  /// plain `zh` and lose against a `zh-Hans` translation. Swift needs no
  /// context threaded in, as `Locale` is globally reachable.
  hwCurrentLocales(
    swift: r'''
func hwCurrentLocales() -> [String] {
  let preferred = Locale.preferredLanguages.map {
    $0.replacingOccurrences(of: "_", with: "-")
  }
  if preferred.isEmpty {
    return [Locale.current.identifier.replacingOccurrences(of: "_", with: "-")]
  }
  return preferred
}''',
    kotlin: '''
private fun hwCurrentLocales(context: Context): List<String> {
    val configured = ConfigurationCompat
        .getLocales(context.resources.configuration)
    val tags = mutableListOf<String>()
    for (index in 0 until configured.size()) {
        val locale = configured[index] ?: continue
        val tag = locale.toLanguageTag()
        if (tag.isNotEmpty() && tag != "und") tags.add(tag)
    }
    if (tags.isEmpty()) {
        val fallback = Locale.getDefault().toLanguageTag()
        if (fallback.isNotEmpty() && fallback != "und") tags.add(fallback)
    }
    return tags
}''',
    kotlinImports: {
      'import android.content.Context',
      'import androidx.core.os.ConfigurationCompat',
      'import java.util.Locale',
    },
  ),

  /// Picks the translation for the first of `locales` that matches, or the one
  /// under `baseLocale`, and null when even that is missing.
  ///
  /// Every entry of the list is tried by progressive truncation first
  /// (`zh-Hant-TW` → `zh-Hant` → `zh`), then against any key sharing its
  /// language with a different region or script (`pt-PT` → `pt-BR`, the
  /// lexicographically smallest key winning so the choice is deterministic).
  ///
  /// Both parts of that order are load-bearing. Truncation before siblings
  /// keeps a `zh-Hant-TW` device on `zh-Hant` instead of whichever of
  /// `zh-Hans`/`zh-Hant` sorts first. The sibling tier keeps compiled
  /// translations on the same text the OS already picks for platform
  /// resources, which get Android's parent-locale matching for free; without
  /// it a `pt-PT` device would render constants in Portuguese and keyed
  /// strings in the default locale.
  ///
  /// The locale list is a parameter on both platforms: a render site that
  /// resolves several strings reads it once rather than per string.
  hwResolveLocalized(
    swift: r'''
func hwResolveLocalized(
  _ locales: [String],
  _ values: [String: String],
  baseLocale: String
) -> String? {
  for tag in locales {
    // Progressive truncation: zh-Hant-TW -> zh-Hant -> zh.
    var candidate = tag.replacingOccurrences(of: "_", with: "-")
    while true {
      if let match = values[candidate] { return match }
      guard let cut = candidate.lastIndex(of: "-"), cut != candidate.startIndex
      else { break }
      candidate = String(candidate[candidate.startIndex..<cut])
    }
    let language = candidate
    // Same language, different region or script (pt-PT -> pt-BR).
    let siblings = values.keys.filter {
      $0.split(separator: "-").first.map(String.init) == language
    }
    if let sibling = siblings.min(), let match = values[sibling] {
      return match
    }
  }
  return values[baseLocale]
}''',
    kotlin: '''
private fun hwResolveLocalized(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String? {
    for (locale in locales) {
        // Progressive truncation: zh-Hant-TW -> zh-Hant -> zh.
        var candidate = locale.replace('_', '-')
        while (true) {
            values[candidate]?.let { return it }
            val cut = candidate.lastIndexOf('-')
            if (cut <= 0) break
            candidate = candidate.substring(0, cut)
        }
        val language = candidate
        // Same language, different region or script (pt-PT -> pt-BR).
        var sibling: String? = null
        for (key in values.keys) {
            if (key.substringBefore('-') != language) continue
            val current = sibling
            if (current == null || key < current) sibling = key
        }
        if (sibling != null) {
            values[sibling]?.let { return it }
        }
    }
    return values[baseLocale]
}''',
  ),

  /// The string entries of a decoded JSON object, skipping anything that is not
  /// text.
  ///
  /// The stored shape of a localized string is one JSON object of locale tag to
  /// text, so a value of another type is a payload the app wrote wrong; it is
  /// dropped rather than rendered or thrown over.
  hwLocalizedEntries(
    swift: '''
func hwLocalizedEntries(_ json: [String: Any]) -> [String: String] {
  var values: [String: String] = [:]
  for (name, value) in json {
    if let text = value as? String { values[name] = text }
  }
  return values
}''',
    kotlin: '''
private fun hwLocalizedEntries(json: JSONObject): Map<String, String> {
    val parsed = mutableMapOf<String, String>()
    val keys = json.keys()
    while (keys.hasNext()) {
        val name = keys.next()
        val value = json.opt(name)
        if (value is String) parsed[name] = value
    }
    return parsed
}''',
    kotlinImports: {'import org.json.JSONObject'},
    localeDependent: false,
  ),

  /// [hwResolveLocalized] for a render site, where a missing translation is
  /// empty text rather than a null the layout would have to branch on.
  hwLocalize(
    swift: '''
func hwLocalize(_ values: [String: String], baseLocale: String) -> String {
  return hwResolveLocalized(hwCurrentLocales(), values, baseLocale: baseLocale) ?? ""
}''',
    kotlin: '''
private fun hwLocalize(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String = hwResolveLocalized(locales, values, baseLocale) ?: ""''',
    dependencies: [
      HWNativeHelper.hwCurrentLocales,
      HWNativeHelper.hwResolveLocalized,
    ],
  ),

  /// Decodes a stored locale map, or null when there is nothing usable.
  ///
  /// Unreadable input — absent, malformed, not an object — leaves the compiled
  /// translations untouched rather than throwing at render time.
  hwDecodeLocalized(
    swift: '''
func hwDecodeLocalized(_ raw: String?) -> [String: String]? {
  guard let raw, let data = raw.data(using: .utf8) else { return nil }
  guard let object = try? JSONSerialization.jsonObject(with: data),
        let json = object as? [String: Any] else { return nil }
  return hwLocalizedEntries(json)
}''',
    kotlin: '''
private fun hwDecodeLocalized(raw: String?): Map<String, String>? {
    if (raw == null) return null
    return try {
        hwLocalizedEntries(JSONObject(raw))
    } catch (_: Exception) {
        null
    }
}''',
    kotlinImports: {'import org.json.JSONObject'},
    dependencies: [HWNativeHelper.hwLocalizedEntries],
    localeDependent: false,
  ),

  /// Resolves a localized string stored under a preferences key.
  ///
  /// The stored value is a single JSON object of locale tag to text, written by
  /// the generated Dart `saveData`. It is laid over the compiled translations
  /// one locale at a time and only the combined map is resolved — the same
  /// merge the generated Dart `getData` performs, so an app read and a widget
  /// render never disagree.
  hwReadLocalized(
    swift: '''
func hwReadLocalized(
  _ defaults: UserDefaults?,
  _ key: String,
  _ values: [String: String],
  baseLocale: String
) -> String {
  var merged = values
  if let stored = hwDecodeLocalized(defaults?.string(forKey: key)) {
    merged.merge(stored) { _, new in new }
  }
  return hwLocalize(merged, baseLocale: baseLocale)
}''',
    kotlin: '''
private fun hwReadLocalized(
    prefs: SharedPreferences,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
    val merged = values.toMutableMap()
    hwDecodeLocalized(prefs.getString(key, null))?.let { merged.putAll(it) }
    return hwLocalize(locales, merged, baseLocale)
}''',
    kotlinImports: {'import android.content.SharedPreferences'},
    dependencies: [
      HWNativeHelper.hwDecodeLocalized,
      HWNativeHelper.hwLocalize,
    ],
  ),

  /// [hwReadLocalized] with the stored locale map taken from the timed entry
  /// active at render time instead of from a preferences key.
  ///
  /// The two must keep resolving alike: making a value time-based may change
  /// when it changes, never which translation a device sees.
  hwReadTimedLocalized(
    swift: '''
func hwReadTimedLocalized(
  _ timedValues: [String: Any],
  _ key: String,
  _ values: [String: String],
  baseLocale: String
) -> String {
  var merged = values
  if let stored = timedValues[key] as? [String: Any] {
    merged.merge(hwLocalizedEntries(stored)) { _, new in new }
  }
  return hwLocalize(merged, baseLocale: baseLocale)
}''',
    kotlin: '''
private fun hwReadTimedLocalized(
    timedValues: JSONObject,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
    val merged = values.toMutableMap()
    timedValues.optJSONObject(key)?.let { merged.putAll(hwLocalizedEntries(it)) }
    return hwLocalize(locales, merged, baseLocale)
}''',
    kotlinImports: {'import org.json.JSONObject'},
    dependencies: [
      HWNativeHelper.hwLocalizedEntries,
      HWNativeHelper.hwLocalize,
    ],
  ),

  /// Decodes an image for display, from a saved file or from a Flutter asset.
  ///
  /// An absolute path is a file the app saved; anything else is a Flutter asset
  /// key, which is both how a bundled image renders and how a gallery preview
  /// stands in for an image the app has not saved yet. On iOS the widget
  /// extension is installed at `Runner.app/PlugIns/<name>.appex`, so the
  /// containing app bundle — and with it `flutter_assets` — is two levels up
  /// from the extension's own bundle; on Android the assets ship inside the APK
  /// under `assets/flutter_assets/`.
  ///
  /// Both platforms cap how much memory a widget may use while rendering, so a
  /// full-resolution photo is downsampled rather than decoded whole. The target
  /// is the image's declared size in pixels. An axis the widget declares no
  /// size for follows the source's aspect ratio on Android, or — with neither
  /// axis declared — falls back to the screen's shorter side, which no widget
  /// exceeds; WidgetKit has no equivalent reading available inside an
  /// extension, so a flat cap of the same order stands in for it. ImageIO
  /// scales to the exact bound, `BitmapFactory` to a power-of-two step.
  ///
  /// A missing file, an unreadable one or a key naming no asset is null, never
  /// a throw at render time.
  hwDecodeImage(
    swift: r'''
func hwDecodeImage(_ path: String, _ widthPt: Double?, _ heightPt: Double?) -> UIImage? {
  func assetFile(_ asset: String) -> String? {
    let appBundleURL = Bundle.main.bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let url = appBundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets")
      .appendingPathComponent(asset)
    return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
  }

  guard let file = path.hasPrefix("/") ? path : assetFile(path),
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil)
  else { return nil }
  let displayScale = UITraitCollection.current.displayScale
  let scale = displayScale > 0 ? displayScale : 3
  let fallback = CGFloat(1536)
  let targetWidth = widthPt.map { CGFloat($0) * scale } ?? fallback
  let targetHeight = heightPt.map { CGFloat($0) * scale } ?? fallback
  let maxPixelSize = Int(max(targetWidth, targetHeight).rounded())
  guard maxPixelSize > 0 else { return nil }
  let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceShouldCacheImmediately: true,
    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
  ]
  guard
    let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  else { return nil }
  return UIImage(cgImage: thumbnail, scale: scale, orientation: .up)
}''',
    kotlin: r'''
private fun hwDecodeImage(
    context: Context,
    path: String,
    widthDp: Double?,
    heightDp: Double?,
): Bitmap? {
    fun decode(options: BitmapFactory.Options): Bitmap? =
        if (path.startsWith("/")) {
            BitmapFactory.decodeFile(path, options)
        } else {
            context.assets.open("flutter_assets/$path").use {
                BitmapFactory.decodeStream(it, null, options)
            }
        }

    fun sampleSize(bounds: BitmapFactory.Options): Int {
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return 1
        val metrics = context.resources.displayMetrics
        val fallback = minOf(metrics.widthPixels, metrics.heightPixels)
        val widthPx = widthDp?.let { (it * metrics.density).toInt() }
        val heightPx = heightDp?.let { (it * metrics.density).toInt() }
        val targetWidth = widthPx
            ?: heightPx?.let {
                (it.toLong() * bounds.outWidth / bounds.outHeight).toInt().coerceAtLeast(1)
            }
            ?: fallback
        val targetHeight = heightPx
            ?: widthPx?.let {
                (it.toLong() * bounds.outHeight / bounds.outWidth).toInt().coerceAtLeast(1)
            }
            ?: fallback
        if (targetWidth <= 0 || targetHeight <= 0) return 1
        var sampleSize = 1
        while (bounds.outWidth / (sampleSize * 2) >= targetWidth &&
            bounds.outHeight / (sampleSize * 2) >= targetHeight) {
            sampleSize *= 2
        }
        return sampleSize
    }

    return try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        decode(bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            null
        } else {
            decode(
                BitmapFactory.Options().apply { inSampleSize = sampleSize(bounds) },
            )
        }
    } catch (_: Exception) {
        null
    }
}''',
    kotlinImports: {
      'import android.content.Context',
      'import android.graphics.Bitmap',
      'import android.graphics.BitmapFactory',
    },
    swiftImports: {'import ImageIO'},
    localeDependent: false,
  );

  const HWNativeHelper({
    required String swift,
    required String kotlin,
    this.kotlinImports = const {},
    this.swiftImports = const {},
    this.dependencies = const [],
    this.localeDependent = true,
  })  : _swift = swift,
        _kotlin = kotlin;

  final String _swift;

  final String _kotlin;

  /// The imports the Kotlin body's short type names stand for.
  @override
  final Set<String> kotlinImports;

  /// The frameworks the Swift body reaches beyond the ones a widget extension
  /// already imports (Foundation, SwiftUI and WidgetKit, and UIKit through
  /// them).
  final Set<String> swiftImports;

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
