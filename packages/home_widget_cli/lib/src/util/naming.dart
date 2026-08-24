/// Converts an arbitrary string into PascalCase suitable for class names.
String toPascalCase(String input) {
  final parts = input
      .trim()
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'Widget';
  }

  return parts.map(_pascalCaseSegment).join();
}

String _pascalCaseSegment(String segment) {
  final upper = segment.toUpperCase();
  final lower = segment.toLowerCase();
  if (segment == upper && segment != lower) {
    return '${upper[0]}${lower.substring(1)}';
  }
  return '${segment[0].toUpperCase()}${segment.substring(1)}';
}

/// The subset of BCP-47 the generator can emit for: `language[-Script][-REGION]`.
///
/// Deliberately narrower than full BCP-47. Variants and extensions
/// (`de-CH-1901`, `zh-Hant-TW-u-ca-chinese`) parse fine but there is no
/// implemented mapping for them, so rejecting them turns silent misgeneration
/// into a clear error.
final RegExp _localeTagPattern = RegExp(
  r'^[A-Za-z]{2,3}(-[A-Za-z]{4})?(-([A-Za-z]{2}|[0-9]{3}))?$',
);

/// Whether [tag] is a locale tag the generator knows how to emit.
///
/// Separators may be `-` or `_`; case is not enforced, since both
/// [localeIdentifier] and [androidLocaleQualifier] normalize it.
bool isWellFormedLocaleTag(String tag) =>
    _localeTagPattern.hasMatch(tag.replaceAll('_', '-'));

/// Converts a BCP-47 locale tag into a Dart identifier.
///
/// `pt-BR` becomes `ptBR`. Reserved words get a trailing underscore — Icelandic
/// is `is`, which would otherwise generate code that does not compile.
String localeIdentifier(String tag) {
  final parts =
      tag.split(RegExp(r'[^A-Za-z0-9]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'locale';

  final buffer = StringBuffer(parts.first.toLowerCase());
  for (final part in parts.skip(1)) {
    buffer.write(
      _pascalCaseSegment(part).toUpperCase() == part.toUpperCase()
          ? part.toUpperCase()
          : _pascalCaseSegment(part),
    );
  }

  final identifier = buffer.toString();
  if (RegExp(r'^[0-9]').hasMatch(identifier)) return 'locale$identifier';
  return _reservedDartWords.contains(identifier)
      ? '${identifier}_'
      : identifier;
}

/// Converts a BCP-47 locale tag into an Android resource directory qualifier.
///
/// Android does not use BCP-47 directly: a region needs the `r` prefix
/// (`pt-BR` → `pt-rBR`), and anything the legacy form cannot express needs the
/// BCP-47 `b+` form (`zh-Hant` → `b+zh+Hant`, `es-419` → `b+es+419`).
/// `b+` qualifiers have been understood since API 17.
String androidLocaleQualifier(String tag) {
  final parts =
      tag.split(RegExp(r'[^A-Za-z0-9]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';

  final language = parts.first.toLowerCase();
  if (parts.length == 1) return language;

  // The legacy form can only express a 2-letter-or-3-letter language plus
  // `-r` + ISO 3166-1 alpha-2 region. A 4-letter script (Hant, Latn) and a
  // UN M.49 numeric region (es-419) both need the BCP-47 `b+` form.
  final needsBcp47 = parts.length > 2 ||
      parts[1].length == 4 ||
      !RegExp(r'^[A-Za-z]{2}$').hasMatch(parts[1]);
  if (needsBcp47) {
    final rest = parts.skip(1).map((p) {
      if (p.length == 4) {
        return '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}';
      }
      return p.toUpperCase();
    });
    return 'b+$language+${rest.join('+')}';
  }

  return '$language-r${parts[1].toUpperCase()}';
}

/// Escapes [value] for use as the text of an Android `<string>` resource.
///
/// XML escaping is handled by the serializer; this covers the aapt-level rules
/// on top of it. Apostrophes are the common one — they appear in most French
/// and Italian copy and are a build error unescaped.
String androidStringResourceText(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('"', r'\"');

/// Whether a `<string>` needs `formatted="false"`.
///
/// A bare `%` reads as a format specifier, and two of them in one string fail
/// the build with "Multiple substitutions specified in non-positional format".
bool androidStringNeedsFormattedFalse(String value) => value.contains('%');

/// Reserved words that cannot be used as a parameter name.
///
/// Deliberately narrower than the validator's keyword list: contextual keywords
/// such as `async` are legal identifiers here.
const Set<String> _reservedDartWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', //
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
};

/// The namespace every platform resource this widget owns is written under.
///
/// Everything matching `home_widget_<snake_widget_class>_` is generated output:
/// the generator rewrites and prunes inside it freely, and never touches
/// anything outside it.
String widgetResourcePrefix(String className) =>
    'home_widget_${toSnakeCase(className)}';

/// Converts a PascalCase or camelCase string into snake_case.
String toSnakeCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return 'widget';

  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    final char = trimmed[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i != 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}
