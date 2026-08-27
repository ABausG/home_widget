/// Shared helpers for embedding arbitrary text in generated source literals.
///
/// Translated copy routinely contains characters that are syntactically
/// meaningful in the target language — quotes, backslashes, Kotlin's `$`
/// interpolation marker, line breaks.
library;

/// Escapes [s] for embedding in a Kotlin double-quoted string literal.
String escapeKotlinStringLiteral(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');

/// Escapes [s] for embedding in a Swift double-quoted string literal.
String escapeSwiftStringLiteral(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');

/// Escapes [s] for embedding in a Dart single-quoted string literal.
String escapeDartStringLiteral(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');
