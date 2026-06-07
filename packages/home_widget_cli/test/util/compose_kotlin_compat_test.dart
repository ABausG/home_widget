import 'package:home_widget_cli/src/util/compose_kotlin_compat.dart';
import 'package:test/test.dart';

void main() {
  group('composeCompilerForKotlin', () {
    test('returns exact match from table', () {
      expect(composeCompilerForKotlin('1.9.25'), '1.5.15');
      expect(composeCompilerForKotlin('1.9.24'), '1.5.14');
      expect(composeCompilerForKotlin('1.9.22'), '1.5.10');
    });

    test('falls back to closest lower patch within same major/minor', () {
      // Not currently in table; should fall back to 1.9.25.
      expect(composeCompilerForKotlin('1.9.26'), '1.5.15');
    });

    test('returns null for unparseable input', () {
      expect(composeCompilerForKotlin(''), isNull);
      expect(composeCompilerForKotlin('foo'), isNull);
      expect(composeCompilerForKotlin('1.9'), isNull);
    });
  });
}
