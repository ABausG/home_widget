import 'package:home_widget_cli/src/util/naming.dart';
import 'package:test/test.dart';

void main() {
  group('androidStringResourceText', () {
    test('escapes the characters aapt treats as syntax', () {
      expect(androidStringResourceText("l'application"), r"l\'application");
      expect(androidStringResourceText('say "hi"'), r'say \"hi\"');
      // The backslash is escaped first, so an escape in the source text stays
      // one character rather than becoming a new escape sequence.
      expect(androidStringResourceText(r'a\b'), r'a\\b');
      expect(androidStringResourceText(r"a\'"), r"a\\\'");
    });

    test('escapes newlines and tabs, which aapt would collapse', () {
      // A literal newline renders as a space on Android while the same
      // translation wraps on iOS.
      expect(androidStringResourceText('Line 1\nLine 2'), r'Line 1\nLine 2');
      expect(androidStringResourceText('Line 1\r\nLine 2'), r'Line 1\nLine 2');
      expect(androidStringResourceText('Line 1\rLine 2'), r'Line 1\nLine 2');
      expect(androidStringResourceText('a\tb'), r'a\tb');
    });

    test('escapes a leading @ or ?, which read as references', () {
      // Unescaped, aapt2 fails the build looking for a resource type `you`.
      expect(androidStringResourceText('@you'), r'\@you');
      expect(androidStringResourceText('?theme'), r'\?theme');
      // Only a *leading* one is syntax.
      expect(androidStringResourceText('mail @you'), 'mail @you');
      expect(androidStringResourceText('really?'), 'really?');
    });

    test('quotes values whose leading or trailing spaces must survive', () {
      expect(androidStringResourceText('Hello '), '"Hello "');
      expect(androidStringResourceText(' Hello'), '" Hello"');
      expect(androidStringResourceText('  padded  '), '"  padded  "');
      // Inner quotes stay escaped inside the quoted form.
      expect(androidStringResourceText('say "hi" '), r'"say \"hi\" "');
      // A leading reference marker is escaped before quoting, so it cannot be
      // read as a reference either way.
      expect(androidStringResourceText('@you '), r'"\@you "');
      // Nothing to preserve, nothing to quote.
      expect(androidStringResourceText('Hello'), 'Hello');
      expect(androidStringResourceText(''), '');
    });
  });

  group('androidStringNeedsFormattedFalse', () {
    test('flags a bare percent sign', () {
      expect(androidStringNeedsFormattedFalse('100% done'), isTrue);
      expect(androidStringNeedsFormattedFalse('done'), isFalse);
    });
  });
}
