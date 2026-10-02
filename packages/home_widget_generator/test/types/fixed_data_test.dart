import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _font = HWIconFont(family: 'MaterialIcons');

void main() {
  group('fixed data', () {
    test('a stored value is not fixed', () {
      const stored = <HWDataType<dynamic>>[
        HWString('label'),
        HWString.localized('title', defaultTranslations: {'en': 'Title'}),
        HWInt('count'),
        HWDouble('ratio'),
        HWBool('flag'),
        HWDateTime('at'),
        HWImageData('avatar'),
        HWIconData('mood', icons: []),
        HWJson('group', HWString('label')),
        HWTimedData(HWString('label')),
        HWItemData(HWString('label')),
      ];

      for (final type in stored) {
        expect(type.isFixed, isFalse, reason: '${type.runtimeType}');
      }
    });

    test('a fixed value carries no key, default or preview', () {
      const fixed = <HWDataType<dynamic>>[
        HWString.fixed('Hi'),
        HWInt.fixed(3),
        HWDouble.fixed(2.5),
        HWBool.fixed(false),
        HWDateTime.fixed('2026-09-22T10:00:00Z'),
        HWIconData.fixed('icon'),
        HWIconData.resolvedFixed(0xe87d, iconFont: _font),
      ];

      for (final type in fixed) {
        expect(type.isFixed, isTrue, reason: '${type.runtimeType}');
        expect(type.key, isEmpty);
        expect(type.defaultValue, isNull);
        expect(type.previewValue, isNull);
      }
    });

    test('the constant forms of an image and a localized string are fixed', () {
      const asset = HWImageData.asset('assets/logo.png');
      const localized = HWString.localizedFixed({'en': 'Hello'});

      expect(asset.isFixed, isTrue);
      expect(localized.isFixed, isTrue);
      expect(localized, isA<HWLocalizedString>());
      expect((localized as HWLocalizedString).isConstant, isTrue);
      expect(localized.key, isEmpty);
      expect(localized.defaultTranslations, {'en': 'Hello'});
      expect(localized.previewTranslations, isNull);
    });

    test('a wrapper around a fixed value is not itself fixed', () {
      expect(const HWTimedData(HWString.fixed('Hi')).isFixed, isFalse);
      expect(const HWItemData(HWInt.fixed(3)).isFixed, isFalse);
      expect(const HWJson('group', HWBool.fixed(true)).isFixed, isFalse);
    });

    group('access is the literal', () {
      test('HWString', () {
        const type = HWString.fixed('He said "Hi" for \$5');

        expect(type.fixedValue, 'He said "Hi" for \$5');
        expect(type.swiftAccess('entry.data'), r'"He said \"Hi\" for $5"');
        expect(type.kotlinAccess('data'), r'"He said \"Hi\" for \$5"');
        expect(
          type.iosToString(outerValue: '"x"', innerValue: '"x"!'),
          '"x"',
        );
        expect(
          type.androidToString(outerValue: '"x"', innerValue: '"x"'),
          '"x"',
        );
      });

      test('HWInt', () {
        const type = HWInt.fixed(-3);

        expect(type.fixedValue, -3);
        expect(type.swiftAccess('entry.data'), '-3');
        expect(type.kotlinAccess('data'), '-3L');
        expect(
          type.iosToString(outerValue: '-3', innerValue: '-3!'),
          r'"\(-3)"',
        );
        expect(
          type.androidToString(outerValue: '-3L', innerValue: '-3L'),
          '(-3L).toString()',
        );
      });

      test('HWDouble', () {
        const type = HWDouble.fixed(2.5);

        expect(type.fixedValue, 2.5);
        expect(type.swiftAccess('entry.data'), '2.5');
        expect(type.kotlinAccess('data'), '2.5');
      });

      test('HWBool', () {
        const type = HWBool.fixed(false);

        expect(type.fixedValue, isFalse);
        expect(type.swiftAccess('entry.data'), 'false');
        expect(type.kotlinAccess('data'), 'false');
      });

      test('HWDateTime parses the instant the way a stored one is read', () {
        const type = HWDateTime.fixed('2026-09-22T10:00:00Z');

        expect(type.fixedIso, '2026-09-22T10:00:00Z');
        expect(type.fixedDateTime, DateTime.utc(2026, 9, 22, 10));
        expect(type.fixedNativeIso, '2026-09-22T10:00:00.000Z');
        expect(
          type.swiftAccess('entry.data'),
          'hwParseIsoDate("2026-09-22T10:00:00.000Z")',
        );
        expect(
          type.kotlinAccess('data'),
          'hwParseIsoDate("2026-09-22T10:00:00.000Z")',
        );
        expect(const HWDateTime.fixed('soon').fixedDateTime, isNull);
        expect(const HWDateTime('at').fixedDateTime, isNull);
        expect(const HWDateTime('at').fixedNativeIso, isNull);
      });

      test('HWDateTime emits one spelling for every way to write an instant',
          () {
        const spellings = {
          '2026-09-22T10:00Z': '2026-09-22T10:00:00.000Z',
          '2026-09-22 10:00:00Z': '2026-09-22T10:00:00.000Z',
          '20260922T100000Z': '2026-09-22T10:00:00.000Z',
          '2026-09-22T10:00:00,5Z': '2026-09-22T10:00:00.500Z',
          '2026-09-22T10:00:00.123456Z': '2026-09-22T10:00:00.123456Z',
          '2026-09-22T12:00:00+02:00': '2026-09-22T10:00:00.000Z',
          '2026-09-22T04:30:00-05:30': '2026-09-22T10:00:00.000Z',
          '2026-09-22T12:00+02': '2026-09-22T10:00:00.000Z',
        };

        for (final MapEntry(key: written, value: emitted)
            in spellings.entries) {
          final type = HWDateTime.fixed(written);

          expect(type.fixedIso, written);
          expect(
            type.swiftAccess('entry.data'),
            'hwParseIsoDate("$emitted")',
            reason: written,
          );
          expect(
            type.kotlinAccess('data'),
            'hwParseIsoDate("$emitted")',
            reason: written,
          );
        }
      });

      test('HWDateTime leaves an instant the validator rejects as written', () {
        for (final written in ['soon', '2026-09-22T10:00:00', '2026-09-22']) {
          final type = HWDateTime.fixed(written);

          expect(
            type.swiftAccess('entry.data'),
            'hwParseIsoDate("$written")',
          );
          expect(type.kotlinAccess('data'), 'hwParseIsoDate("$written")');
        }
      });

      test('HWIconData once decoded', () {
        const type = HWIconData.resolvedFixed(
          0xe5c4,
          iconFont: _font,
          matchTextDirection: true,
        );

        expect(type.swiftAccess('entry.data'), '0xE5C4');
        expect(type.kotlinAccess('data'), '0xE5C4');
        expect(type.codePoints, {0xe5c4});
        expect(type.mirroredCodePoints, {0xe5c4});
        expect(type.entries, isEmpty);
        expect(type.validate, returnsNormally);
        expect(
          const HWIconData.resolvedFixed(0xe87d, iconFont: _font)
              .mirroredCodePoints,
          isEmpty,
        );
      });

      test('a stored value still reads off the data class', () {
        expect(const HWString('label').swiftAccess('d'), 'd.label');
        expect(const HWInt('count').kotlinAccess('d'), 'd.count');
        expect(const HWDouble('ratio').swiftAccess('d'), 'd.ratio');
        expect(const HWBool('flag').kotlinAccess('d'), 'd.flag');
        expect(const HWBool('flag').swiftAccess('d'), 'd.flag');
        expect(const HWDateTime('at').swiftAccess('d'), 'd.at');
        expect(const HWDateTime('at').kotlinAccess('d'), 'd.at');
        expect(
          const HWIconData.resolved(
            'mood',
            entries: [HWIconEntry('cloud', 0xe2bd)],
            iconFont: _font,
          ).swiftAccess('d'),
          'd.mood',
        );
        expect(
          const HWIconData('mood', icons: []).kotlinAccess('d'),
          'd.mood',
        );
      });
    });

    group('equality', () {
      test('tells two fixed values of one type apart by their content', () {
        expect(const HWString.fixed('a'), const HWString.fixed('a'));
        expect(const HWString.fixed('a'), isNot(const HWString.fixed('b')));
        expect(
          const HWString.fixed('a').hashCode,
          const HWString.fixed('a').hashCode,
        );
        expect(const HWInt.fixed(1), isNot(const HWInt.fixed(2)));
        expect(const HWDouble.fixed(1), isNot(const HWDouble.fixed(2)));
        expect(const HWBool.fixed(true), isNot(const HWBool.fixed(false)));
        expect(
          const HWDateTime.fixed('2026-09-22T10:00:00Z'),
          isNot(const HWDateTime.fixed('2026-09-23T10:00:00Z')),
        );
        expect(
          const HWDateTime.fixed('2026-09-22T10:00:00Z').hashCode,
          const HWDateTime.fixed('2026-09-22T10:00:00Z').hashCode,
        );
        expect(
          const HWIconData.resolvedFixed(1, iconFont: _font),
          isNot(const HWIconData.resolvedFixed(2, iconFont: _font)),
        );
        expect(
          const HWIconData.resolvedFixed(1, iconFont: _font),
          isNot(
            const HWIconData.resolvedFixed(
              1,
              iconFont: _font,
              matchTextDirection: true,
            ),
          ),
        );
        expect(
          const HWIconData.resolvedFixed(1, iconFont: _font).hashCode,
          const HWIconData.resolvedFixed(1, iconFont: _font).hashCode,
        );
        expect(
          const HWIconData.fixed('a'),
          isNot(const HWIconData.fixed('b')),
        );
      });

      test('keeps a fixed value apart from a stored one', () {
        expect(const HWString.fixed(''), isNot(const HWString('')));
        expect(const HWInt.fixed(0), isNot(const HWInt('')));
        expect(
          const HWDateTime.fixed('2026-09-22T10:00:00Z'),
          isNot(const HWDateTime('', previewValue: '2026-09-22T10:00:00Z')),
        );
      });
    });

    group('merging', () {
      const pairs = <(HWDataType<dynamic>, HWDataType<dynamic>)>[
        (HWString.fixed('a'), HWString.fixed('a')),
        (HWString.fixed('a'), HWString('')),
        (HWString(''), HWString.fixed('a')),
        (HWInt.fixed(1), HWInt.fixed(1)),
        (HWDouble.fixed(1), HWDouble.fixed(1)),
        (HWBool.fixed(true), HWBool.fixed(true)),
        (
          HWDateTime.fixed('2026-09-22T10:00:00Z'),
          HWDateTime.fixed('2026-09-22T10:00:00Z'),
        ),
        (HWDateTime(''), HWDateTime.fixed('2026-09-22T10:00:00Z')),
        (
          HWIconData.resolvedFixed(1, iconFont: _font),
          HWIconData.resolvedFixed(1, iconFont: _font),
        ),
      ];

      test('a fixed value is compatible with nothing, not even its equal', () {
        for (final (a, b) in pairs) {
          expect(a.isCompatibleWith(b), isFalse, reason: '$a / $b');
        }
      });

      test('merging one is a conflict', () {
        for (final (a, b) in pairs) {
          expect(
            () => a.mergedWith(b),
            throwsA(isA<GeneratorError>()),
            reason: '$a / $b',
          );
        }
      });
    });
  });
}
