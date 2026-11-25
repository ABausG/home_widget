import 'package:home_widget_generator/src/utils/string_literals.dart';
import 'package:test/test.dart';

void main() {
  group('kotlinLongLiteral', () {
    test('suffixes a whole number with L', () {
      expect(kotlinLongLiteral(0), '0L');
      expect(kotlinLongLiteral(-3), '-3L');
      expect(kotlinLongLiteral(9223372036854775807), '9223372036854775807L');
    });

    test('names the smallest Long, which has no literal', () {
      expect(kotlinLongLiteral(-9223372036854775808), 'Long.MIN_VALUE');
    });
  });

  group('dartIntLiteral', () {
    test('writes a number a double holds exactly as itself', () {
      expect(dartIntLiteral(0), '0');
      expect(dartIntLiteral(9007199254740992), '9007199254740992');
      expect(dartIntLiteral(-9007199254740992), '-9007199254740992');
    });

    test('splits a larger number into parts that each fit', () {
      expect(dartIntLiteral(9007199254740993), '(2097152 * 4294967296 + 1)');
      expect(
        dartIntLiteral(-9007199254740993),
        '(-2097153 * 4294967296 + 4294967295)',
      );
      expect(
        dartIntLiteral(-9223372036854775808),
        '(-2147483648 * 4294967296 + 0)',
      );
      expect(
        dartIntLiteral(9223372036854775807),
        '(2147483647 * 4294967296 + 4294967295)',
      );
    });
  });

  group('escapeKotlinStringLiteral', () {
    test('escapes every character that would end or reinterpret the literal',
        () {
      expect(escapeKotlinStringLiteral(r'a\b'), r'a\\b');
      expect(escapeKotlinStringLiteral('a"b'), r'a\"b');
      expect(escapeKotlinStringLiteral(r'a$b'), r'a\$b');
      expect(escapeKotlinStringLiteral('a\nb'), r'a\nb');
      expect(escapeKotlinStringLiteral('a\rb'), r'a\rb');
      expect(escapeKotlinStringLiteral('a\tb'), r'a\tb');
    });

    test('escapes the interpolation marker so `\$name` stays literal text', () {
      expect(
        escapeKotlinStringLiteral(r'$name and ${expr}'),
        r'\$name and \${expr}',
      );
    });

    test('leaves single quotes alone, since the target is double-quoted', () {
      expect(escapeKotlinStringLiteral("it's"), "it's");
    });

    test('escapes the backslash first, so `\\n` is not read as a newline', () {
      expect(escapeKotlinStringLiteral(r'a\nb'), r'a\\nb');
    });

    test('collapses real line breaks so the literal stays on one line', () {
      expect(escapeKotlinStringLiteral('a\nb\r\nc').split('\n'), hasLength(1));
    });

    test('passes ordinary text through untouched', () {
      expect(escapeKotlinStringLiteral('Guten Morgen'), 'Guten Morgen');
      expect(escapeKotlinStringLiteral(''), '');
    });
  });

  group('escapeSwiftStringLiteral', () {
    test('escapes every character that would end or reinterpret the literal',
        () {
      expect(escapeSwiftStringLiteral(r'a\b'), r'a\\b');
      expect(escapeSwiftStringLiteral('a"b'), r'a\"b');
      expect(escapeSwiftStringLiteral('a\nb'), r'a\nb');
      expect(escapeSwiftStringLiteral('a\rb'), r'a\rb');
      expect(escapeSwiftStringLiteral('a\tb'), r'a\tb');
    });

    test('leaves `\$` alone, because Swift does not interpolate on it', () {
      expect(escapeSwiftStringLiteral(r'$9.99'), r'$9.99');
    });

    test('neutralises Swift interpolation by escaping its backslash', () {
      // `\(expr)` only interpolates while the backslash is unescaped.
      expect(escapeSwiftStringLiteral(r'\(expr)'), r'\\(expr)');
    });

    test('collapses real line breaks so the literal stays on one line', () {
      expect(escapeSwiftStringLiteral('a\nb\r\nc').split('\n'), hasLength(1));
    });

    test('passes ordinary text through untouched', () {
      expect(escapeSwiftStringLiteral('Guten Morgen'), 'Guten Morgen');
      expect(escapeSwiftStringLiteral(''), '');
    });
  });

  group('escapeDartStringLiteral', () {
    test('escapes every character that would end or reinterpret the literal',
        () {
      expect(escapeDartStringLiteral(r'a\b'), r'a\\b');
      expect(escapeDartStringLiteral("a'b"), r"a\'b");
      expect(escapeDartStringLiteral(r'a$b'), r'a\$b');
      expect(escapeDartStringLiteral('a\nb'), r'a\nb');
      expect(escapeDartStringLiteral('a\rb'), r'a\rb');
      expect(escapeDartStringLiteral('a\tb'), r'a\tb');
    });

    test('escapes the interpolation marker so `\$name` stays literal text', () {
      expect(
        escapeDartStringLiteral(r'$name and ${expr}'),
        r'\$name and \${expr}',
      );
    });

    test('leaves double quotes alone, since the target is single-quoted', () {
      expect(escapeDartStringLiteral('say "hi"'), 'say "hi"');
    });

    test('escapes the backslash first, so `\\n` is not read as a newline', () {
      expect(escapeDartStringLiteral(r'a\nb'), r'a\\nb');
    });

    test('collapses real line breaks so the literal stays on one line', () {
      expect(escapeDartStringLiteral('a\nb\r\nc').split('\n'), hasLength(1));
    });

    test('handles the whole escape set at once', () {
      expect(
        escapeDartStringLiteral("\\'\$\n\r\t"),
        r"\\\'\$\n\r\t",
      );
    });

    test('passes ordinary text through untouched', () {
      expect(escapeDartStringLiteral('Guten Morgen'), 'Guten Morgen');
      expect(escapeDartStringLiteral(''), '');
    });
  });
}
