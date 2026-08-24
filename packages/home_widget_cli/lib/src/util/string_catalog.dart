import 'dart:convert';

/// Builds the contents of an Xcode String Catalog (`Localizable.xcstrings`).
///
/// The catalog is the iOS counterpart to `res/values-<locale>/strings.xml`:
/// translations that are fixed at build time ship as a resource so the system
/// resolves them against the user's full preferred-language list, instead of
/// the widget matching locales itself at render time.
///
/// [entries] maps resource name to a locale-tag → text map, which must include
/// the [sourceLanguage] entry. Keys and locales are sorted so regenerating an
/// unchanged widget produces a byte-identical file.
///
/// `extractionState: manual` tells Xcode these strings were not found by
/// scanning source, which stops it from marking them stale and offering to
/// delete them.
String stringCatalogJson({
  required String sourceLanguage,
  required Map<String, Map<String, String>> entries,
}) {
  final strings = <String, dynamic>{};
  for (final name in entries.keys.toList()..sort()) {
    final values = entries[name]!;
    final localizations = <String, dynamic>{};
    for (final locale in values.keys.toList()..sort()) {
      localizations[locale] = <String, dynamic>{
        'stringUnit': <String, dynamic>{
          'state': 'translated',
          'value': values[locale],
        },
      };
    }
    strings[name] = <String, dynamic>{
      'extractionState': 'manual',
      'localizations': localizations,
    };
  }

  final catalog = <String, dynamic>{
    'sourceLanguage': sourceLanguage,
    'strings': strings,
    'version': '1.0',
  };

  return '${const JsonEncoder.withIndent('  ').convert(catalog)}\n';
}
