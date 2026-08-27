/// Locale-resolution helpers injected into generated widget sources.
///
/// Only keyed strings and localized JSON leaves reach these: their translations
/// are compiled into the widget rather than shipped as platform resources, so
/// the widget has to match locales itself. Constant strings
/// (`HWText.localized`) and the gallery name and description are resources,
/// resolved by the OS.
///
/// Resolution walks the user's *entire* preferred-language list in order. Each
/// entry is tried by progressive truncation first (`zh-Hant-TW` → `zh-Hant` →
/// `zh`), then against any key sharing its language with a different region or
/// script (`pt-PT` → `pt-BR`; the lexicographically smallest key wins, so the
/// choice is deterministic). The widget's default locale applies only once the
/// whole list is exhausted.
///
/// Both parts of that order are load-bearing. Truncation before siblings keeps
/// a `zh-Hant-TW` device on `zh-Hant` instead of whichever of
/// `zh-Hans`/`zh-Hant` sorts first. The sibling tier keeps keyed strings on the
/// translation the OS already picks for constants, which get Android's
/// parent-locale matching for free; without it a `pt-PT` device would render
/// constants in Portuguese and keyed strings in the default locale.
library;

/// Kotlin resolver for compiled translations, emitted when a widget resolves
/// any translation itself.
///
/// Reads tags via `toLanguageTag()`: `getLanguage()` still returns the obsolete
/// ISO-639 codes (iw, in, ji) and drops the script subtag.
const String kotlinLocalizeHelpers = '''
private fun hwCurrentLocales(context: android.content.Context): List<String> {
    val configured = androidx.core.os.ConfigurationCompat
        .getLocales(context.resources.configuration)
    val tags = mutableListOf<String>()
    for (index in 0 until configured.size()) {
        val locale = configured[index] ?: continue
        val tag = locale.toLanguageTag()
        if (tag.isNotEmpty() && tag != "und") tags.add(tag)
    }
    if (tags.isEmpty()) {
        val fallback = java.util.Locale.getDefault().toLanguageTag()
        if (fallback.isNotEmpty() && fallback != "und") tags.add(fallback)
    }
    return tags
}

// Returns null when nothing matches, including under the base locale.
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
}''';

/// Kotlin reader for a keyed localized string.
///
/// The stored value is a single JSON object of locale tag to text, written by
/// the generated Dart `saveData`. It is laid over the compiled translations one
/// locale at a time and only the combined map is resolved — the same merge the
/// generated Dart `getData` performs, so an app read and a widget render never
/// disagree. Unreadable input (absent, malformed, not an object) leaves the
/// compiled translations untouched rather than throwing.
const String kotlinLocalizedReadHelper = '''
private fun hwReadLocalized(
    prefs: android.content.SharedPreferences,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
    val merged = values.toMutableMap()
    hwDecodeLocalized(prefs.getString(key, null))?.let { merged.putAll(it) }
    return hwLocalize(locales, merged, baseLocale)
}

private fun hwDecodeLocalized(raw: String?): Map<String, String>? {
    if (raw == null) return null
    return try {
        val json = org.json.JSONObject(raw)
        val parsed = mutableMapOf<String, String>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val name = keys.next()
            val value = json.opt(name)
            if (value is String) parsed[name] = value
        }
        parsed
    } catch (_: Exception) {
        null
    }
}

private fun hwLocalize(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String = hwResolveLocalized(locales, values, baseLocale) ?: ""''';

/// Swift resolver for compiled translations. Mirrors [kotlinLocalizeHelpers],
/// but needs no context threaded in — `Locale` is globally reachable.
const String swiftLocalizeHelpers = '''
func hwCurrentLocales() -> [String] {
  let preferred = Locale.preferredLanguages.map {
    \$0.replacingOccurrences(of: "_", with: "-")
  }
  if preferred.isEmpty {
    return [Locale.current.identifier.replacingOccurrences(of: "_", with: "-")]
  }
  return preferred
}

// Returns nil when nothing matches, including under the base locale.
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
      \$0.split(separator: "-").first.map(String.init) == language
    }
    if let sibling = siblings.min(), let match = values[sibling] {
      return match
    }
  }
  return values[baseLocale]
}''';

/// Swift reader for a keyed localized string. Mirrors
/// [kotlinLocalizedReadHelper].
const String swiftLocalizedReadHelper = '''
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
}

func hwDecodeLocalized(_ raw: String?) -> [String: String]? {
  guard let raw, let data = raw.data(using: .utf8) else { return nil }
  guard let object = try? JSONSerialization.jsonObject(with: data),
        let json = object as? [String: Any] else { return nil }
  var values: [String: String] = [:]
  for (name, value) in json {
    if let text = value as? String { values[name] = text }
  }
  return values
}

func hwLocalize(_ values: [String: String], baseLocale: String) -> String {
  return hwResolveLocalized(hwCurrentLocales(), values, baseLocale: baseLocale) ?? ""
}''';
