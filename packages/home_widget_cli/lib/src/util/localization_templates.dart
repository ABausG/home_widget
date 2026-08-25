/// Locale-resolution helpers injected into generated widget sources.
///
/// These serve keyed strings only. A keyed string's runtime override lives in
/// one preferences blob and its fallback is compiled into the widget, so
/// neither tier is a platform resource and the widget has to do the matching
/// itself. Constant strings (`HWText.localized`) and the gallery name and
/// description are platform resources, resolved by the OS, and never reach
/// these helpers.
///
/// Resolution walks the user's *entire* preferred-language list in order — a
/// device set to `[de-AT, fr, en]` should get French before it falls back to the
/// widget's default locale. Each entry is tried as an exact tag (`pt-BR`), then
/// as its language alone (`pt`), and finally against any key sharing that
/// language but carrying a different region or script (`pt-PT` → `pt-BR`); only
/// once the whole list is exhausted does the widget's default locale apply.
///
/// The region-sibling tier exists so keyed strings land on the same translation
/// the OS picks for constant strings, which are platform resources and get
/// Android's parent-locale matching for free. Without it a `pt-PT` device would
/// render constants in Portuguese and keyed strings in the default locale.
/// Several siblings can match (`pt-BR` and `pt-MZ`); the lexicographically
/// smallest key wins so generation and behavior stay deterministic.
///
/// The base value is looked up in the map under `baseLocale` rather than passed
/// separately, so the same string is never emitted twice.
library;

/// Kotlin resolver for compiled translations. Emitted when a widget contains
/// any keyed localized string.
const String kotlinLocalizeHelpers = '''
private fun hwCurrentLocales(context: android.content.Context): List<String> {
    val configured = androidx.core.os.ConfigurationCompat
        .getLocales(context.resources.configuration)
    val tags = mutableListOf<String>()
    for (index in 0 until configured.size()) {
        val locale = configured[index] ?: continue
        val tag = if (locale.country.isNullOrEmpty()) {
            locale.language
        } else {
            "\${locale.language}-\${locale.country}"
        }
        if (tag.isNotEmpty()) tags.add(tag.replace('_', '-'))
    }
    if (tags.isEmpty()) {
        val fallback = java.util.Locale.getDefault()
        tags.add(
            if (fallback.country.isNullOrEmpty()) {
                fallback.language
            } else {
                "\${fallback.language}-\${fallback.country}"
            }
        )
    }
    return tags
}

// Returns null when nothing in [values] matches, so a caller holding a second
// tier of translations can fall through to it.
private fun hwResolveLocalized(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String? {
    for (locale in locales) {
        val tag = locale.replace('_', '-')
        values[tag]?.let { return it }
        val language = tag.substringBefore('-')
        values[language]?.let { return it }
        // Same language, different region or script (pt-PT -> pt-BR). Keeps
        // keyed strings on the translation the OS already picks for resources.
        // Smallest key wins so the choice is stable across runs.
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
}

private fun hwLocalize(
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String = hwResolveLocalized(locales, values, baseLocale) ?: ""''';

/// Kotlin reader for a keyed localized string.
///
/// The stored value is a single JSON object mapping locale tag to text, written
/// by the generated Dart `saveData`. It is checked before the compiled
/// translations so a value pushed from Dart wins, and resolution happens inside
/// it on every render so a locale change is picked up without the app having to
/// run again.
///
/// Anything unreadable — absent, malformed, not an object, no matching locale —
/// falls through to the compiled defaults rather than throwing.
const String kotlinLocalizedReadHelper = '''
private fun hwReadLocalized(
    prefs: android.content.SharedPreferences,
    key: String,
    locales: List<String>,
    values: Map<String, String>,
    baseLocale: String,
): String {
    val stored = hwDecodeLocalized(prefs.getString(key, null))
    if (stored != null) {
        hwResolveLocalized(locales, stored, baseLocale)?.let { return it }
    }
    return hwLocalize(locales, values, baseLocale)
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
}''';

/// Swift resolver for compiled translations.
///
/// Unlike Kotlin this needs nothing threaded in — `Locale` is reachable from
/// anywhere in the extension process.
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

// Returns nil when nothing in `values` matches, so a caller holding a second
// tier of translations can fall through to it.
func hwResolveLocalized(
  _ locales: [String],
  _ values: [String: String],
  baseLocale: String
) -> String? {
  for tag in locales {
    if let exact = values[tag] { return exact }
    guard let prefix = tag.split(separator: "-").first else { continue }
    let language = String(prefix)
    if let match = values[language] { return match }
    // Same language, different region or script (pt-PT -> pt-BR). Keeps keyed
    // strings on the translation the OS already picks for resources. Smallest
    // key wins so the choice is stable across runs.
    let siblings = values.keys.filter {
      \$0.split(separator: "-").first.map(String.init) == language
    }
    if let sibling = siblings.min(), let match = values[sibling] {
      return match
    }
  }
  return values[baseLocale]
}

func hwLocalize(_ values: [String: String], baseLocale: String) -> String {
  return hwResolveLocalized(hwCurrentLocales(), values, baseLocale: baseLocale) ?? ""
}''';

/// Swift reader for a keyed localized string.
///
/// Mirrors [kotlinLocalizedReadHelper]: one stored JSON object per key, checked
/// before the compiled translations, and never fatal when unreadable.
const String swiftLocalizedReadHelper = '''
func hwReadLocalized(
  _ defaults: UserDefaults?,
  _ key: String,
  _ values: [String: String],
  baseLocale: String
) -> String {
  let locales = hwCurrentLocales()
  if let stored = hwDecodeLocalized(defaults?.string(forKey: key)),
     let match = hwResolveLocalized(locales, stored, baseLocale: baseLocale) {
    return match
  }
  return hwResolveLocalized(locales, values, baseLocale: baseLocale) ?? ""
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
}''';
