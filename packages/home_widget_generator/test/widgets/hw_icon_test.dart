import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';
import 'package:home_widget_generator/src/utils/apply_swift_modifier.dart';
import 'package:home_widget_generator/src/utils/inject_glance_modifier.dart';
import 'package:test/test.dart';

const _materialIcons = HWIconFont(family: 'MaterialIcons');

const _mood = HWIconData.resolved(
  'mood',
  entries: [
    HWIconEntry('wbSunny', 0xE88A),
    HWIconEntry('cloud', 0xE42D),
  ],
  iconFont: _materialIcons,
);

const _arrows = HWIconData.resolved(
  'arrow',
  entries: [
    HWIconEntry('arrowForward', 0xE5C8, matchTextDirection: true),
    HWIconEntry('cloud', 0xE42D),
    HWIconEntry('arrowBack', 0xE5C4, matchTextDirection: true),
  ],
  iconFont: _materialIcons,
);

void main() {
  group('HWIcon model', () {
    test('a constant icon knows its glyph and font', () {
      const icon = HWIcon.glyph(0xE88A, font: _materialIcons);
      expect(icon.codePoint, 0xE88A);
      expect(icon.iconFont, _materialIcons);
      expect(icon.dataType, isNull);
      expect(icon.dataDependencies, isEmpty);
      expect(icon.size, 24);
      expect(icon.semanticLabel, isNull);
    });

    test('a bound icon reads its font off the data type', () {
      const icon = HWIcon(_mood);
      expect(icon.codePoint, isNull);
      expect(icon.iconData, _mood);
      expect(icon.iconFont, _materialIcons);
      expect(icon.dataDependencies, {_mood});
    });

    test('finds the icon through HWTimedData and HWJson', () {
      expect(const HWIcon(HWTimedData(_mood)).iconData, _mood);
      expect(const HWIcon(HWJson('weather', _mood)).iconData, _mood);
      expect(
        const HWIcon(HWTimedData(HWJson('weather', _mood))).iconData,
        _mood,
      );
    });

    test('defaults to the platform primary content color', () {
      expect(
        const HWIcon(_mood).effectiveColor,
        const HWDefaultColor(HWColorRole.contentPrimary),
      );
      expect(
        const HWIcon(_mood, color: HWFixedColor(0xFFFF0000)).effectiveColor,
        const HWFixedColor(0xFFFF0000),
      );
    });

    test('knows which of its glyphs mirror in a right-to-left layout', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons).matchTextDirection,
        isFalse,
      );
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons).mirroredCodePoints,
        isEmpty,
      );
      expect(
        const HWIcon.glyph(
          0xE5C4,
          font: _materialIcons,
          matchTextDirection: true,
        ).mirroredCodePoints,
        {0xE5C4},
      );
      expect(const HWIcon(_mood).mirroredCodePoints, isEmpty);
      expect(const HWIcon(_arrows).mirroredCodePoints, {0xE5C4, 0xE5C8});
    });

    test('throws when it is handed something other than an icon', () {
      expect(
        () => const HWIcon(HWString('label')).iconData,
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('HWIcon requires an HWIconData'),
          ),
        ),
      );
    });

    test('throws when the icon never went through the decoder', () {
      expect(
        () => const HWIcon.fixed('Icons.home').iconFont,
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('The font of this HWIcon is unknown'),
          ),
        ),
      );
    });
  });

  group('HWIcon iOS', () {
    test('renders a constant glyph out of the bundled font', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toSwift(0, dataExpr: 'data'),
        'Text(String(UnicodeScalar(UInt32(0xE88A))!))\n'
        '    .font(hwBundledFont("hw_font_icons_materialicons", size: 24))\n'
        '    .foregroundColor(Color.primary)\n'
        '    .accessibilityHidden(true)',
      );
    });

    test('renders a bound glyph and skips a widget with no value', () {
      expect(
        const HWIcon(_mood, size: 32, color: HWFixedColor(0xFF00FF00))
            .toSwift(0, dataExpr: 'entry.widgetData'),
        'if let codePoint = entry.widgetData.mood, '
        'let scalar = UnicodeScalar(UInt32(codePoint)) {\n'
        '    Text(String(scalar))\n'
        '        .font(hwBundledFont("hw_font_icons_materialicons", size: 32))\n'
        '        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.0, '
        'opacity: 1.0))\n'
        '        .accessibilityHidden(true)\n'
        '}',
      );
    });

    test('reads a bound glyph out of a JSON group', () {
      expect(
        const HWIcon(HWJson('weather', _mood)).toSwift(0, dataExpr: 'data'),
        contains('if let codePoint = data.weather?.mood,'),
      );
    });

    test('describes itself when there is a semantic label', () {
      expect(
        const HWIcon.glyph(
          0xE88A,
          font: _materialIcons,
          semanticLabel: 'Sunny',
        ).toSwift(0, dataExpr: 'data'),
        contains('.accessibilityLabel("Sunny")'),
      );
    });

    test('mirrors a directional constant glyph', () {
      expect(
        const HWIcon.glyph(
          0xE5C4,
          font: _materialIcons,
          matchTextDirection: true,
        ).toSwift(0, dataExpr: 'data'),
        'Text(String(UnicodeScalar(UInt32(0xE5C4))!))\n'
        '    .font(hwBundledFont("hw_font_icons_materialicons", size: 24))\n'
        '    .foregroundColor(Color.primary)\n'
        '    .accessibilityHidden(true)\n'
        '    .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)',
      );
    });

    test('mirrors only the directional glyphs of a bound icon', () {
      expect(
        const HWIcon(_arrows).toSwift(0, dataExpr: 'data'),
        'if let codePoint = data.arrow, '
        'let scalar = UnicodeScalar(UInt32(codePoint)) {\n'
        '    Text(String(scalar))\n'
        '        .font(hwBundledFont("hw_font_icons_materialicons", size: 24))\n'
        '        .foregroundColor(Color.primary)\n'
        '        .accessibilityHidden(true)\n'
        '        .scaleEffect(x: layoutDirection == .rightToLeft && '
        '[0xE5C4, 0xE5C8].contains(codePoint) ? -1 : 1, y: 1)\n'
        '}',
      );
    });

    test('leaves an undirectional icon alone', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toSwift(0, dataExpr: 'data'),
        isNot(contains('scaleEffect')),
      );
      expect(
        const HWIcon(_mood).toSwift(0, dataExpr: 'data'),
        isNot(contains('scaleEffect')),
      );
    });

    test('declares the layout direction only where it reads it', () {
      expect(const HWIcon(_mood).swiftViewModifiers, isEmpty);
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons).swiftViewModifiers,
        isEmpty,
      );
      expect(
        const HWIcon.glyph(
          0xE5C4,
          font: _materialIcons,
          matchTextDirection: true,
        ).swiftViewModifiers,
        {r'@Environment(\.layoutDirection) var layoutDirection'},
      );
      expect(
        const HWIcon(_arrows).swiftViewModifiers,
        {r'@Environment(\.layoutDirection) var layoutDirection'},
      );
      expect(
        const HWColumn(children: [HWIcon(_arrows)]).swiftViewModifiers,
        contains(r'@Environment(\.layoutDirection) var layoutDirection'),
      );
    });

    test('keeps the indentation of its level and takes a view modifier', () {
      final swift = const HWIcon.glyph(0xE88A, font: _materialIcons)
          .toSwift(1, dataExpr: 'data');
      expect(swift, startsWith('    Text('));
      expect(
        applySwiftModifier(swift, '.padding(4)', 1),
        endsWith('\n    .padding(4)'),
      );
    });
  });

  group('HWIcon Android', () {
    test('renders a constant glyph as a tinted bitmap', () {
      expect(
        const HWIcon.glyph(
          0xE88A,
          font: _materialIcons,
          fontResourcePrefix: 'hw_font_forecast',
        ).toKotlin(0, dataExpr: 'data'),
        'Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, '
        'R.font.hw_font_forecast_icons_materialicons, 0xE88A, 24f)), '
        'contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))',
      );
    });

    test('renders a bound glyph and skips a widget with no value', () {
      expect(
        const HWIcon(
          _mood,
          size: 32,
          semanticLabel: 'Mood',
          fontResourcePrefix: 'hw_font_forecast',
        ).toKotlin(0, dataExpr: 'data'),
        'data.mood?.let { codePoint ->\n'
        '    Image(modifier = GlanceModifier.size(32.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap('
        'context, R.font.hw_font_forecast_icons_materialicons, codePoint, '
        '32f)), contentDescription = "Mood", '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))\n'
        '}',
      );
    });

    test('mirrors a directional constant glyph', () {
      expect(
        const HWIcon.glyph(
          0xE5C4,
          font: _materialIcons,
          matchTextDirection: true,
          fontResourcePrefix: 'hw_font_forecast',
        ).toKotlin(0, dataExpr: 'data'),
        'Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, '
        'R.font.hw_font_forecast_icons_materialicons, 0xE5C4, 24f, '
        'matchTextDirection = true)), '
        'contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))',
      );
    });

    test('mirrors only the directional glyphs of a bound icon', () {
      expect(
        const HWIcon(_arrows, fontResourcePrefix: 'hw_font_forecast')
            .toKotlin(0, dataExpr: 'data'),
        'data.arrow?.let { codePoint ->\n'
        '    Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap('
        'context, R.font.hw_font_forecast_icons_materialicons, codePoint, '
        '24f, matchTextDirection = codePoint in setOf(0xE5C4, 0xE5C8))), '
        'contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))\n'
        '}',
      );
    });

    test('leaves the argument out for an undirectional icon', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toKotlin(0, dataExpr: 'data'),
        isNot(contains('matchTextDirection')),
      );
      expect(
        const HWIcon(_mood).toKotlin(0, dataExpr: 'data'),
        isNot(contains('matchTextDirection')),
      );
    });

    test('falls back to a widget-less font resource', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toKotlin(0, dataExpr: 'data'),
        contains('R.font.hw_font_home_widget_icons_materialicons'),
      );
    });

    test('takes an injected modifier onto its own', () {
      expect(
        injectGlanceModifier(
          const HWIcon.glyph(0xE88A, font: _materialIcons)
              .toKotlin(0, dataExpr: 'data'),
          'padding(4.dp)',
        ),
        contains('modifier = GlanceModifier.padding(4.dp).size(24.dp)'),
      );
    });

    test('imports what the call needs', () {
      expect(
        const HWIcon(_mood).kotlinImports,
        containsAll(<String>[
          'import androidx.compose.ui.unit.dp',
          'import androidx.glance.ColorFilter',
          'import androidx.glance.GlanceModifier',
          'import androidx.glance.Image',
          'import androidx.glance.ImageProvider',
          'import androidx.glance.layout.size',
          'import androidx.glance.GlanceTheme',
          'import es.antonborri.home_widget.HomeWidgetFonts',
        ]),
      );
    });
  });

  group('iconCodePoints', () {
    test('unions the glyphs of a tree per font', () {
      const cupertino =
          HWIconFont(family: 'CupertinoIcons', package: 'cupertino_icons');
      const tree = HWColumn(
        children: [
          HWIcon.glyph(0xE87D, font: _materialIcons),
          HWRow(
            children: [
              HWIcon(_mood),
              HWIcon.glyph(0xF4B6, font: cupertino),
              HWText.fixed('no icon'),
            ],
          ),
        ],
      );

      expect(tree.iconCodePoints, {
        _materialIcons: {0xE87D, 0xE88A, 0xE42D},
        cupertino: {0xF4B6},
      });
    });

    test('is empty for a tree without icons', () {
      expect(
        const HWColumn(children: [HWText.fixed('a')]).iconCodePoints,
        isEmpty,
      );
    });

    test('contributes nothing for an icon that never went through the decoder',
        () {
      expect(const HWIcon.fixed('Icons.home').ownIconCodePoints, isEmpty);
    });
  });
}
