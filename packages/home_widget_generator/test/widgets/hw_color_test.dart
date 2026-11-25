import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';
import 'package:test/test.dart';

String expectedKotlinColor(HWColorRole role) {
  return switch (role) {
    HWColorRole.contentPrimary => 'GlanceTheme.colors.onSurface',
    HWColorRole.contentSecondary => 'GlanceTheme.colors.onSurfaceVariant',
    HWColorRole.contentTertiary => 'GlanceTheme.colors.outline',
    HWColorRole.contentAccent => 'GlanceTheme.colors.primaryContainer',
    HWColorRole.defaultBackground => 'GlanceTheme.colors.widgetBackground',
  };
}

String expectedSwiftColor(HWColorRole role) {
  return switch (role) {
    HWColorRole.contentPrimary => 'Color.primary',
    HWColorRole.contentSecondary => 'Color.secondary',
    HWColorRole.contentTertiary => 'Color(.tertiaryLabel)',
    HWColorRole.contentAccent => 'Color.accentColor',
    HWColorRole.defaultBackground => 'Color.clear',
  };
}

const _content = HWColorSlotDefault.content;
const _transparent = HWColorSlotDefault.transparent;

void main() {
  group('HWDefaultColor', () {
    for (final role in HWColorRole.values) {
      test('role "${role.name}" maps to its Glance and SwiftUI color', () {
        final color = HWDefaultColor(role);
        expect(
          hwKotlinColor(color, dataExpr: 'data', fallback: _content),
          expectedKotlinColor(role),
        );
        expect(
          hwSwiftColor(color, dataExpr: 'data', fallback: _content),
          expectedSwiftColor(role),
        );
      });
    }

    test('pulls GlanceTheme into the Kotlin imports', () {
      expect(
        hwKotlinColorImports(
          const HWDefaultColor(HWColorRole.contentPrimary),
          fallback: _transparent,
        ),
        contains('import androidx.glance.GlanceTheme'),
      );
    });

    test('is a fixed value with no field and no helper', () {
      const color = HWDefaultColor(HWColorRole.contentAccent);
      expect(color.isFixed, isTrue);
      expect(color.isDataDependency, isFalse);
      expect(color.renderHelpers, isEmpty);
    });
  });

  group('HWFixedColor', () {
    test('HWColor.fixed is an HWFixedColor', () {
      const color = HWColor.fixed(0xFF00FF00);
      expect(color, isA<HWFixedColor>());
      expect((color as HWFixedColor).value, 0xFF00FF00);
    });

    test('paints its own literal on both platforms, needing no fallback', () {
      const color = HWColor.fixed(0x80FF0000);
      expect(
        hwKotlinColor(color, dataExpr: 'data', fallback: _content),
        'ColorProvider(day = Color(0x80FF0000), night = Color(0x80FF0000))',
      );
      expect(
        hwSwiftColor(color, dataExpr: 'data', fallback: _content),
        'Color(red: 1.0, green: 0.0, blue: 0.0, '
        'opacity: 0.5019607843137255)',
      );
    });

    test('spells a negative value by its low 32 bits on Android', () {
      expect(const HWFixedColor(-1).kotlinLiteral, 'Color(0xFFFFFFFF)');
      expect(const HWFixedColor(0xFF6750A4).kotlinLiteral, 'Color(0xFF6750A4)');
    });

    test('compares by value', () {
      expect(const HWFixedColor(1), const HWFixedColor(1));
      expect(const HWFixedColor(1), isNot(const HWFixedColor(2)));
      expect(
        const HWFixedColor(1).hashCode,
        const HWFixedColor(1).hashCode,
      );
    });
  });

  group('HWColor', () {
    const accent = HWColor(
      'accent',
      defaultValue: 0xFF6750A4,
      previewValue: 0xFF000000,
    );

    test('is a stored field of its own', () {
      expect(accent.isFixed, isFalse);
      expect(accent.isDataDependency, isTrue);
      expect(accent.renderHelpers, {HWNativeHelper.hwColor});
    });

    test('hands a Flutter Color over and back as a 32-bit ARGB int', () {
      expect(accent.dartType, 'int');
      expect(accent.dartApiType('W'), 'Color');
      expect(accent.dartGetDataType('W'), 'Color');
      expect(accent.dartDecode('raw', 'W'), r'_$color(raw)');
      expect(
        accent.dartEncode('accent', 'W'),
        'accent.withValues(colorSpace: ColorSpace.sRGB).toARGB32()',
      );
      expect(accent.codegenDartDefaultLiteral(), '0xFF6750A4');
      expect(const HWColor('plain').codegenDartDefaultLiteral(), isNull);
    });

    test('reads as an int on iOS and a Long on Android', () {
      expect(accent.swiftType, 'Int');
      expect(accent.kotlinType, 'Long');
      expect(
        accent.iosReadValue(store: 'defaults', key: 'k'),
        '(defaults?.object(forKey: "k") as? Int ?? 0xFF6750A4)',
      );
      expect(
        accent.iosReadValue(store: 'defaults', key: 'k', preview: true),
        '(defaults?.object(forKey: "k") as? Int ?? 0xFF000000)',
      );
      expect(
        const HWColor('plain').iosReadValue(store: 'defaults', key: 'k'),
        'defaults?.object(forKey: "k") as? Int',
      );
      expect(
        accent.androidReadValue(store: 'prefs', key: 'k'),
        '(hwReadColor(prefs, "k") ?: 4284960932L)',
      );
      expect(
        accent.androidReadValue(store: 'prefs', key: 'k', preview: true),
        '(hwReadColor(prefs, "k") ?: 4278190080L)',
      );
      expect(
        const HWColor('plain').androidReadValue(store: 'prefs', key: 'k'),
        'hwReadColor(prefs, "k")',
      );
    });

    test('reads a key through hwReadColor, which tells Int and Long apart', () {
      expect(accent.nativeHelpers, [HWNativeHelper.hwReadColor]);
      expect(accent.timedNativeHelpers, isEmpty);
      expect(accent.jsonNativeHelpers, isEmpty);
      expect(const HWColor.fixed(0xFF000000).nativeHelpers, isEmpty);
      expect(
        const HWDefaultColor(HWColorRole.contentPrimary).nativeHelpers,
        isEmpty,
      );

      final kotlin = HWNativeHelper.hwReadColor.kotlin!;
      expect(
        kotlin,
        contains(
          'prefs.getLong(key, 0L).takeIf { it == prefs.getLong(key, 1L) }',
        ),
      );
      expect(
        kotlin,
        contains(
          'prefs.getInt(key, 0).takeIf { it == prefs.getInt(key, 1) }'
          '?.toLong()',
        ),
      );
      expect(kotlin, isNot(contains('prefs.contains(')));
      expect(kotlin, isNot(contains('.all')));
      expect(HWNativeHelper.hwReadColor.swift, isNull);
      expect(
        HWNativeHelper.hwReadColor.kotlinImports,
        {'import android.content.SharedPreferences'},
      );
    });

    test('paints through hwColor, falling back to the slot default', () {
      expect(
        hwSwiftColor(accent, dataExpr: 'entry.data'),
        'hwColor(entry.data.accent)',
      );
      expect(
        hwSwiftColor(accent, dataExpr: 'entry.data', fallback: _transparent),
        '(hwColor(entry.data.accent) ?? Color.clear)',
      );
      expect(
        hwKotlinColor(accent, dataExpr: 'widgetData', fallback: _content),
        '(hwColor(widgetData.accent) ?: GlanceTheme.colors.onSurface)',
      );
      expect(
        hwKotlinColorImports(accent, fallback: _content),
        containsAll([
          'import androidx.glance.GlanceTheme',
          'import androidx.glance.color.ColorProvider',
        ]),
      );
    });

    test('reads a JSON leaf with its default, and an item off the item', () {
      const json = HWJson('brand', HWColor('fill', defaultValue: 0xFF112233));
      expect(
        hwSwiftColor(json, dataExpr: 'd'),
        'hwColor((((d.brand?.fill) ?? (0xFF112233))))',
      );
      expect(
        hwKotlinColor(json, dataExpr: 'd', fallback: _transparent),
        startsWith('(hwColor((d.brand?.fill ?: 4279312947L)) ?: '),
      );
      const item = HWItemData(HWColor('tint'));
      expect(hwSwiftColor(item, dataExpr: 'd'), 'hwColor(hwItem.tint)');
      expect(
        hwKotlinColor(item, dataExpr: 'd', fallback: _transparent),
        '(hwColor(hwItem.tint) ?: '
        'ColorProvider(day = Color.Transparent, night = Color.Transparent))',
      );
    });

    test('merges compatible declarations', () {
      final merged = const HWColor('a', defaultValue: 1)
          .mergedWith(const HWColor('a', previewValue: 2)) as HWColor;
      expect(merged.defaultValue, 1);
      expect(merged.previewValue, 2);
      expect(
        const HWColor('a', defaultValue: 1)
            .isCompatibleWith(const HWColor('a', defaultValue: 2)),
        isFalse,
      );
      expect(
        const HWColor('a').isCompatibleWith(const HWFixedColor(1)),
        isFalse,
      );
    });

    test('is not display text', () {
      expect(
        () => accent.iosToString(outerValue: 'x', innerValue: 'x'),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('the color stored under "accent"'),
          ),
        ),
      );
      expect(
        () => const HWFixedColor(0xFF000000)
            .androidToString(outerValue: 'x', innerValue: 'x'),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('HWColor.fixed(0xFF000000)'),
          ),
        ),
      );
    });

    test('hwArgbLiteral spells the low 32 bits in upper-case hex', () {
      expect(hwArgbLiteral(0xFF6750A4), '0xFF6750A4');
      expect(hwArgbLiteral(0x00000000), '0x00000000');
      expect(hwArgbLiteral(-1), '0xFFFFFFFF');
    });
  });

  group('HWAppearanceData of colors', () {
    test('two constant colors stay a ColorProvider pair on Android', () {
      const pair = HWAppearanceData<int>(
        light: HWColor.fixed(0xFFFFFFFF),
        dark: HWColor.fixed(0xFF000000),
      );
      expect(pair.kotlinIsFixedColorPair, isTrue);
      expect(
        hwKotlinColor(pair, dataExpr: 'd', fallback: _content),
        'ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF000000))',
      );
      expect(pair.renderHelpers, {HWNativeHelper.hwAppearance});
      expect(
        hwKotlinColorImports(pair, fallback: _content),
        isNot(contains('import androidx.glance.GlanceTheme')),
      );
    });

    test('a role on one side is resolved into the pair, not as white', () {
      const mixed = HWAppearanceData<int>(
        light: HWDefaultColor(HWColorRole.contentPrimary),
        dark: HWColor.fixed(0xFF000000),
      );
      expect(mixed.kotlinIsFixedColorPair, isFalse);
      final kotlin = hwKotlinColor(mixed, dataExpr: 'd', fallback: _content);
      expect(
        kotlin,
        '(hwAppearanceColor(context, GlanceTheme.colors.onSurface, '
        'ColorProvider(day = Color(0xFF000000), night = Color(0xFF000000))) '
        '?: GlanceTheme.colors.onSurface)',
      );
      expect(kotlin, isNot(contains('Color.White')));
      expect(
        hwSwiftColor(mixed, dataExpr: 'd'),
        'hwAppearance(hwEnvironment, light: Color.primary, '
        'dark: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0))',
      );
      expect(
        mixed.renderHelpers,
        {HWNativeHelper.hwAppearance, HWNativeHelper.hwAppearanceColor},
      );
    });

    test('stored sides with the iOS slots', () {
      const stored = HWAppearanceData<int>(
        light: HWColor('light'),
        dark: HWColor('dark'),
        iosAccented: HWColor.fixed(0xFFFFFFFF),
        iosVibrant: HWDefaultColor(HWColorRole.contentPrimary),
      );
      expect(
        hwSwiftColor(stored, dataExpr: 'e', fallback: _transparent),
        '(hwAppearance(hwEnvironment, light: hwColor(e.light), '
        'dark: hwColor(e.dark), '
        'accented: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0), '
        'vibrant: Color.primary) ?? Color.clear)',
      );
      expect(
        hwKotlinColor(stored, dataExpr: 'w', fallback: _transparent),
        '(hwAppearanceColor(context, hwColor(w.light), hwColor(w.dark)) ?: '
        'ColorProvider(day = Color.Transparent, night = Color.Transparent))',
      );
      expect(
        hwKotlinColorImports(stored, fallback: _content),
        contains('import androidx.glance.GlanceTheme'),
      );
      expect(stored.swiftViewModifiers, {
        HWAppearanceChoice.swiftEnvironmentDeclaration,
      });
    });
  });

  group('HWColorSlotDefault', () {
    test('names what each slot paints without a value', () {
      expect(HWColorSlotDefault.content.swift, isNull);
      expect(HWColorSlotDefault.transparent.swift, 'Color.clear');
      expect(
        HWColorSlotDefault.background.kotlin,
        'GlanceTheme.colors.widgetBackground',
      );
      expect(
        HWColorSlotDefault.background.kotlinImports,
        {'import androidx.glance.GlanceTheme'},
      );
      expect(HWColorSlotDefault.background.swift, isNull);
      expect(
        hwSwiftColor(
          const HWColor('a'),
          dataExpr: 'e',
          fallback: HWColorSlotDefault.content,
        ),
        'hwColor(e.a)',
      );
    });

    test('hwIsConstantColor is only true for a fixed or role color', () {
      expect(hwIsConstantColor(const HWColor.fixed(1)), isTrue);
      expect(
        hwIsConstantColor(const HWDefaultColor(HWColorRole.contentAccent)),
        isTrue,
      );
      expect(hwIsConstantColor(const HWColor('a')), isFalse);
      expect(
        hwIsConstantColor(
          const HWAppearanceData<int>(
            light: HWColor.fixed(1),
            dark: HWColor.fixed(2),
          ),
        ),
        isFalse,
      );
    });

    test('a pick between constant colors is constant on iOS', () {
      const pick = HWAppearanceData<int>(
        light: HWColor.fixed(0xFF000000),
        dark: HWDefaultColor(HWColorRole.contentPrimary),
      );
      expect(hwSwiftColorIsConstant(pick), isTrue);
      expect(hwSwiftColorIsConstant(const HWColor.fixed(1)), isTrue);
      expect(
        hwSwiftColorIsConstant(
          const HWAppearanceData<int>(
            light: HWColor('a'),
            dark: HWColor.fixed(1),
          ),
        ),
        isFalse,
      );
      expect(
        hwSwiftConstantColor(pick, dataExpr: 'e'),
        '(hwAppearance(hwEnvironment, '
        'light: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0), '
        'dark: Color.primary) ?? '
        'Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0))',
      );
      expect(
        hwSwiftConstantColor(
          const HWDefaultColor(HWColorRole.contentPrimary),
          dataExpr: 'e',
        ),
        'Color.primary',
      );
    });
  });
}
