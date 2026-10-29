/// Shared helpers for embedding values in generated source literals.
///
/// Translated copy routinely contains characters that are syntactically
/// meaningful in the target language — quotes, backslashes, Kotlin's `$`
/// interpolation marker, line breaks.
library;

import '../generator_error.dart';

/// [size] as a literal both platforms read as a number, without the trailing
/// `.0` a whole Dart double stringifies with.
String hwSizeLiteral(double size) =>
    size == size.toInt() ? size.toInt().toString() : size.toString();

/// [codePoint] as the hexadecimal literal a glyph is usually written as, which
/// both platforms read the same way.
String hwCodePointLiteral(int codePoint) =>
    '0x${codePoint.toRadixString(16).toUpperCase()}';

/// Throws a [GeneratorError] when [codePoint] is no glyph a widget can be
/// generated for, naming [source] as what holds it.
///
/// A value outside the Unicode range is not a codepoint at all and comes out as
/// a literal neither Kotlin nor Swift compiles; a surrogate is half of one and
/// has no glyph of its own, which the rendered code would only find out at
/// runtime.
void hwValidateCodePoint(int codePoint, String source) {
  if (codePoint < 0 || codePoint > 0x10FFFF) {
    throw GeneratorError(
      '$source names the codepoint $codePoint, which is outside the Unicode '
      'range 0x0 to 0x10FFFF.',
    );
  }
  if (codePoint >= 0xD800 && codePoint <= 0xDFFF) {
    throw GeneratorError(
      '$source names the codepoint ${hwCodePointLiteral(codePoint)}, which is '
      'a surrogate: half of a codepoint rather than a glyph of its own.',
    );
  }
}

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
