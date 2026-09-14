import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _materialIcons = HWIconFont(family: 'MaterialIcons');

const _entries = [
  HWIconEntry('wbSunny', 0xE88A),
  HWIconEntry('cloud', 0xE42D),
];

HWIconData _mood({int? defaultValue, int? previewValue}) => HWIconData.resolved(
      'mood',
      entries: _entries,
      iconFont: _materialIcons,
      defaultValue: defaultValue,
      previewValue: previewValue,
    );

Matcher _throwsGeneratorError(Object message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );

void main() {
  group('HWIconEntry', () {
    test('equality and description', () {
      const entry = HWIconEntry('wbSunny', 0xE88A);
      expect(entry, _entries.first);
      expect(entry.hashCode, _entries.first.hashCode);
      expect(entry, isNot(const HWIconEntry('sunny', 0xE88A)));
      expect(entry.toString(), 'HWIconEntry(wbSunny, 0xE88A)');
    });

    test('a directional entry differs from an undirectional one', () {
      const directional =
          HWIconEntry('arrowBack', 0xE5C4, matchTextDirection: true);
      expect(directional.matchTextDirection, isTrue);
      const plain = HWIconEntry('arrowBack', 0xE5C4);
      expect(plain.matchTextDirection, isFalse);
      expect(directional, isNot(const HWIconEntry('arrowBack', 0xE5C4)));
      expect(
        directional.hashCode,
        isNot(const HWIconEntry('arrowBack', 0xE5C4).hashCode),
      );
      expect(
        directional,
        const HWIconEntry('arrowBack', 0xE5C4, matchTextDirection: true),
      );
    });
  });

  group('HWIconData model', () {
    test('a decoded field knows its glyphs and its font', () {
      final icons = _mood(defaultValue: 0xE88A, previewValue: 0xE42D);
      expect(icons.key, 'mood');
      expect(icons.entries, _entries);
      expect(icons.iconFont, _materialIcons);
      expect(icons.codePoints, {0xE88A, 0xE42D});
      expect(icons.defaultValue, 0xE88A);
      expect(icons.previewValue, 0xE42D);
    });

    test('an annotation-space field only carries what was written', () {
      const icons = HWIconData('mood', icons: ['Icons.wb_sunny']);
      expect(icons.icons, ['Icons.wb_sunny']);
      expect(icons.entries, isEmpty);
      expect(icons.iconFont, isNull);
      expect(icons.defaultValue, isNull);
      expect(icons.previewValue, isNull);
    });

    test('is stored as a plain int on both platforms', () {
      final icons = _mood();
      expect(icons.dartType, 'int');
      expect(icons.kotlinType, 'Int');
      expect(icons.swiftType, 'Int');
    });

    test('collects the glyphs that mirror in a right-to-left layout', () {
      expect(_mood().mirroredCodePoints, isEmpty);
      expect(
        HWIconData.resolved(
          'mood',
          entries: const [
            HWIconEntry('arrowBack', 0xE5C4, matchTextDirection: true),
            HWIconEntry('cloud', 0xE42D),
            HWIconEntry('arrowForward', 0xE5C8, matchTextDirection: true),
          ],
          iconFont: _materialIcons,
        ).mirroredCodePoints,
        {0xE5C4, 0xE5C8},
      );
    });

    test('names the generated enum after the widget and the key', () {
      expect(_mood().enumSuffix, 'MoodIcon');
      expect(_mood().enumNameFor('Forecast'), 'ForecastMoodIcon');
      expect(
        HWIconData.resolved(
          'mood_of_day',
          entries: _entries,
          iconFont: _materialIcons,
        ).enumSuffix,
        'MoodOfDayIcon',
      );
    });
  });

  group('HWIconData validation', () {
    test('rejects a field with no icons', () {
      expect(
        () => HWIconData.resolved(
          'mood',
          entries: const [],
          iconFont: _materialIcons,
        ).validate(),
        _throwsGeneratorError('HWIconData "mood" needs at least one icon.'),
      );
    });

    test('rejects two icons that would become the same enum value', () {
      expect(
        () => HWIconData.resolved(
          'mood',
          entries: const [
            HWIconEntry('cloud', 0xE42D),
            HWIconEntry('cloud', 0xE43A),
          ],
          iconFont: _materialIcons,
        ).validate(),
        _throwsGeneratorError(contains('names the icon "cloud" twice')),
      );
    });

    test('rejects two names for one glyph, as Flutter aliases are', () {
      expect(
        () => HWIconData.resolved(
          'mood',
          entries: const [
            HWIconEntry('airplanemodeActive', 0xE06E),
            HWIconEntry('airplanemodeOn', 0xE06E),
          ],
          iconFont: _materialIcons,
        ).validate(),
        _throwsGeneratorError(
          allOf(
            contains('"airplanemodeActive"'),
            contains('"airplanemodeOn"'),
            contains('0xE06E'),
          ),
        ),
      );
    });

    test('rejects a default that is not one of the icons', () {
      expect(
        () => _mood(defaultValue: 0xE001).validate(),
        _throwsGeneratorError(
          'The defaultValue of HWIconData "mood" is not one of its icons.',
        ),
      );
    });

    test('rejects a preview that is not one of the icons', () {
      expect(
        () => _mood(previewValue: 0xE001).validate(),
        _throwsGeneratorError(
          'The previewValue of HWIconData "mood" is not one of its icons.',
        ),
      );
    });

    test('accepts a field whose default and preview are icons of its own', () {
      final icons = _mood(defaultValue: 0xE88A, previewValue: 0xE42D);
      expect(icons.validate, returnsNormally);
    });
  });

  group('HWIconData codegen', () {
    test('Android reads the codepoint as an Int', () {
      expect(
        _mood().androidReadValue(store: 'prefs', key: 'mood'),
        'if (prefs.contains("mood")) prefs.getInt("mood", 0) else null',
      );
      expect(
        _mood(defaultValue: 0xE88A)
            .androidReadValue(store: 'prefs', key: 'mood'),
        'if (prefs.contains("mood")) prefs.getInt("mood", 0) else 59530',
      );
      expect(
        _mood(previewValue: 0xE42D)
            .androidReadValue(store: 'prefs', key: 'mood', preview: true),
        'if (prefs.contains("mood")) prefs.getInt("mood", 0) else 58413',
      );
    });

    test('iOS reads the codepoint as an Int', () {
      expect(
        _mood().iosReadValue(store: 'defaults', key: 'mood'),
        'defaults?.object(forKey: "mood") as? Int',
      );
      expect(
        _mood(defaultValue: 0xE88A)
            .iosReadValue(store: 'defaults', key: 'mood'),
        '(defaults?.object(forKey: "mood") as? Int ?? 59530)',
      );
    });

    test('cannot be rendered as text', () {
      final notText =
          _throwsGeneratorError(contains('cannot be rendered as text'));
      expect(
        () => _mood().androidToString(outerValue: 'v', innerValue: 'v'),
        notText,
      );
      expect(
        () => _mood().iosToString(outerValue: 'v', innerValue: 'v'),
        notText,
      );
    });
  });

  group('HWIconData merging', () {
    test('two declarations of the same field merge their extras', () {
      final merged = _mood(defaultValue: 0xE88A)
          .mergedWith(_mood(previewValue: 0xE42D)) as HWIconData;
      expect(merged.defaultValue, 0xE88A);
      expect(merged.previewValue, 0xE42D);
      expect(merged.entries, _entries);
      expect(merged.iconFont, _materialIcons);
    });

    test('a different icon list is a conflict', () {
      expect(
        () => _mood().mergedWith(
          HWIconData.resolved(
            'mood',
            entries: const [HWIconEntry('cloud', 0xE42D)],
            iconFont: _materialIcons,
          ),
        ),
        _throwsGeneratorError(contains('Conflicting declarations')),
      );
    });

    test('a different font is a conflict', () {
      expect(
        () => _mood().mergedWith(
          HWIconData.resolved(
            'mood',
            entries: _entries,
            iconFont: const HWIconFont(family: 'CupertinoIcons'),
          ),
        ),
        _throwsGeneratorError(contains('Conflicting declarations')),
      );
    });

    test('equality covers the icons, the font and the defaults', () {
      expect(_mood(), _mood());
      expect(_mood().hashCode, _mood().hashCode);
      expect(_mood(), isNot(_mood(defaultValue: 0xE88A)));
      expect(
        const HWIconData('mood', icons: ['a']),
        isNot(const HWIconData('mood', icons: ['b'])),
      );
    });
  });

  group('iconLeafOf', () {
    test('descends every wrapper an icon may sit in', () {
      final icons = _mood();
      expect(iconLeafOf(icons), icons);
      expect(iconLeafOf(HWTimedData(icons)), icons);
      expect(iconLeafOf(HWJson('weather', icons)), icons);
      expect(iconLeafOf(HWTimedData(HWJson('weather', icons))), icons);
    });

    test('is null for anything else', () {
      expect(iconLeafOf(const HWString('label')), isNull);
      expect(iconLeafOf(const HWJson('profile', HWInt('age'))), isNull);
    });
  });
}
