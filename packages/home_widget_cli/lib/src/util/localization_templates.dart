/// Locale-resolution helpers injected into generated widget sources.
///
/// Translations are inlined rather than shipped as platform resource files, so
/// each widget carries the small amount of matching logic it needs. Resolution
/// is exact tag (`pt-BR`) → language (`pt`) → the widget's default locale.
///
/// The base value is looked up in the map under `baseLocale` rather than passed
/// separately, so the same string is never emitted twice.
library;

/// Kotlin resolver for inlined translations. Always emitted when a widget
/// contains any localized string.
const String kotlinLocalizeHelpers = '''
private fun hwCurrentLocale(context: android.content.Context): String {
    val locale = androidx.core.os.ConfigurationCompat
        .getLocales(context.resources.configuration)[0]
        ?: java.util.Locale.getDefault()
    return if (locale.country.isNullOrEmpty()) {
        locale.language
    } else {
        "\${locale.language}-\${locale.country}"
    }
}

private fun hwLocalize(locale: String, values: Map<String, String>, baseLocale: String): String {
    val tag = locale.replace('_', '-')
    return values[tag]
        ?: values[tag.substringBefore('-')]
        ?: values[baseLocale]
        ?: ""
}''';

/// Kotlin reader for a keyed localized string.
///
/// Preferences are checked before the compiled translations so a value pushed
/// from Dart wins, and per locale so a locale change is picked up without the
/// app having to run again.
const String kotlinLocalizedReadHelper = '''
private fun hwReadLocalized(
    prefs: android.content.SharedPreferences,
    key: String,
    locale: String,
    values: Map<String, String>,
    baseLocale: String,
): String {
    val tag = locale.replace('_', '-')
    return prefs.getString("\$key.\$tag", null)
        ?: prefs.getString("\$key.\${tag.substringBefore('-')}", null)
        ?: prefs.getString("\$key.\$baseLocale", null)
        ?: hwLocalize(tag, values, baseLocale)
}''';

/// Swift resolver for inlined translations.
///
/// Unlike Kotlin this needs nothing threaded in — `Locale` is reachable from
/// anywhere in the extension process.
const String swiftLocalizeHelpers = '''
func hwCurrentLocale() -> String {
  let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
  return identifier.replacingOccurrences(of: "_", with: "-")
}

func hwLocalize(_ values: [String: String], baseLocale: String) -> String {
  let tag = hwCurrentLocale()
  if let exact = values[tag] { return exact }
  if let language = tag.split(separator: "-").first,
     let match = values[String(language)] {
    return match
  }
  return values[baseLocale] ?? ""
}''';

/// Swift reader for a keyed localized string.
const String swiftLocalizedReadHelper = '''
func hwReadLocalized(
  _ defaults: UserDefaults?,
  _ key: String,
  _ values: [String: String],
  baseLocale: String
) -> String {
  let tag = hwCurrentLocale()
  if let exact = defaults?.string(forKey: "\\(key).\\(tag)") { return exact }
  if let language = tag.split(separator: "-").first,
     let match = defaults?.string(forKey: "\\(key).\\(language)") {
    return match
  }
  if let fallback = defaults?.string(forKey: "\\(key).\\(baseLocale)") {
    return fallback
  }
  return hwLocalize(values, baseLocale: baseLocale)
}''';
