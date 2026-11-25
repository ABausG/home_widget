import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/utils/fixed_spelling.dart';
import 'package:test/test.dart';

void main() {
  group('spellFixedValue', () {
    test('spells every fixed value the way a schema writes it', () {
      const spellings = <(HWDataType<dynamic>, String)>[
        (HWString.fixed('Hi'), 'HWString.fixed("Hi")'),
        (HWString.localizedFixed({'en': 'Hello'}), 'HWString.localizedFixed'),
        (
          HWDateTime.fixed('2026-09-22T10:00:00Z'),
          'HWDateTime.fixed("2026-09-22T10:00:00Z")',
        ),
        (
          HWImageData.asset('assets/logo.png'),
          'HWImageData.asset("assets/logo.png")',
        ),
        (
          HWIconData.resolvedFixed(
            0xe87d,
            iconFont: HWIconFont(family: 'MaterialIcons'),
          ),
          'HWIconData.fixed',
        ),
        (HWInt.fixed(3), 'HWInt.fixed(3)'),
        (HWDouble.fixed(2.5), 'HWDouble.fixed(2.5)'),
        (HWBool.fixed(true), 'HWBool.fixed(true)'),
      ];

      for (final (value, spelling) in spellings) {
        expect(spellFixedValue(value), spelling);
      }
    });

    test('names a wrapper, which has no fixed form, by its type', () {
      expect(
        spellFixedValue(const HWJson('user', HWString('name'))),
        startsWith('HWJson'),
      );
      expect(
        spellFixedValue(const HWTimedData(HWString('name'))),
        startsWith('HWTimedData'),
      );
      expect(
        spellFixedValue(const HWItemData(HWString('name'))),
        startsWith('HWItemData'),
      );
    });
  });
}
