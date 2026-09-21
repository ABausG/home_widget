import 'package:home_widget_generator/home_widget_generator.dart';
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

    test('a frame larger than the glyph centers it', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons).swiftFrameAlignment,
        '.center',
      );
      expect(const HWIcon(_mood).swiftFrameAlignment, '.center');
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

    test('reads an item field off the item a builder renders', () {
      const icon = HWIcon.resolved(
        HWItemData(_mood),
        fontResourcePrefix: 'hw_font_forecast',
      );

      expect(icon.iconData, _mood);
      expect(icon.dataDependencies, {const HWItemData(_mood)});
      expect(icon.ownIconCodePoints, {
        _materialIcons: {0xE88A, 0xE42D},
      });
      expect(
        icon.toSwift(0, dataExpr: 'entry.data'),
        startsWith(
          'if let codePoint = hwItem.mood, '
          'let value = UInt32(exactly: codePoint), '
          'let scalar = UnicodeScalar(value) {',
        ),
      );
      expect(
        icon.toKotlin(0, dataExpr: 'widgetData'),
        startsWith('hwItem.mood?.let { codePoint ->'),
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

    test('knows whether a constant glyph mirrors in a right-to-left layout',
        () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons).matchTextDirection,
        isFalse,
      );
      expect(
        const HWIcon.glyph(
          0xE5C4,
          font: _materialIcons,
          matchTextDirection: true,
        ).matchTextDirection,
        isTrue,
      );
      expect(const HWIcon(_arrows).matchTextDirection, isFalse);
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

    test('only the resolved constructors carry a font resource prefix', () {
      expect(const HWIcon(_mood).fontResourcePrefix, isNull);
      expect(const HWIcon.fixed('Icons.home').fontResourcePrefix, isNull);
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons).fontResourcePrefix,
        isNull,
      );
      expect(
        const HWIcon.resolved(_mood, fontResourcePrefix: 'hw_font_forecast')
            .fontResourcePrefix,
        'hw_font_forecast',
      );
      expect(
        const HWIcon.resolvedGlyph(
          0xE88A,
          font: _materialIcons,
          fontResourcePrefix: 'hw_font_forecast',
        ).fontResourcePrefix,
        'hw_font_forecast',
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

    test('renders an undecoded icon as that same error, not a null check', () {
      const icon = HWIcon.fixed('Icons.home');
      final unknownFont = throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          contains('The font of this HWIcon is unknown'),
        ),
      );

      expect(() => icon.toSwift(0, dataExpr: 'data'), unknownFont);
      expect(() => icon.toKotlin(0, dataExpr: 'data'), unknownFont);
    });

    test('throws for a glyph outside the Unicode range', () {
      final outsideRange = throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          contains('outside the Unicode range'),
        ),
      );

      expect(
        () => const HWIcon.glyph(-1, font: _materialIcons)
            .toSwift(0, dataExpr: 'data'),
        outsideRange,
      );
      expect(
        () => const HWIcon.glyph(-1, font: _materialIcons)
            .toKotlin(0, dataExpr: 'data'),
        outsideRange,
      );
      expect(
        () => const HWIcon.glyph(0x110000, font: _materialIcons)
            .toSwift(0, dataExpr: 'data'),
        outsideRange,
      );
    });

    test('throws for a glyph that is half a codepoint', () {
      final surrogate = throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          contains('surrogate'),
        ),
      );

      expect(
        () => const HWIcon.glyph(0xD800, font: _materialIcons)
            .toSwift(0, dataExpr: 'data'),
        surrogate,
      );
      expect(
        () => const HWIcon.glyph(0xDFFF, font: _materialIcons)
            .toKotlin(0, dataExpr: 'data'),
        surrogate,
      );
    });

    test('renders the glyphs at either end of the range', () {
      expect(
        const HWIcon.glyph(0, font: _materialIcons).toSwift(0, dataExpr: 'd'),
        contains('UInt32(0x0)'),
      );
      expect(
        const HWIcon.glyph(0x10FFFF, font: _materialIcons)
            .toKotlin(0, dataExpr: 'd'),
        contains('0x10FFFF'),
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
        '    .frame(width: 24, height: 24)\n'
        '    .foregroundColor(Color.primary)\n'
        '    .accessibilityHidden(true)',
      );
    });

    test('renders a bound glyph and skips a widget with no value', () {
      expect(
        const HWIcon(_mood, size: 32, color: HWFixedColor(0xFF00FF00))
            .toSwift(0, dataExpr: 'entry.widgetData'),
        'if let codePoint = entry.widgetData.mood, '
        'let value = UInt32(exactly: codePoint), '
        'let scalar = UnicodeScalar(value) {\n'
        '    Text(String(scalar))\n'
        '        .font(hwBundledFont("hw_font_icons_materialicons", size: 32))\n'
        '        .frame(width: 32, height: 32)\n'
        '        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.0, '
        'opacity: 1.0))\n'
        '        .accessibilityHidden(true)\n'
        '        .scaleEffect(x: layoutDirection == .rightToLeft && '
        'hwMirroredIcons.contains(codePoint) ? -1 : 1, y: 1)\n'
        '}',
      );
    });

    test('turns a stored value no glyph can come of into no icon', () {
      expect(
        const HWIcon(_mood).toSwift(0, dataExpr: 'data'),
        contains('let value = UInt32(exactly: codePoint)'),
      );
      expect(
        const HWIcon(_mood).toSwift(0, dataExpr: 'data'),
        isNot(contains('UnicodeScalar(UInt32(codePoint))')),
      );
    });

    test('reads a bound glyph out of a JSON group', () {
      expect(
        const HWIcon(HWJson('weather', _mood)).toSwift(0, dataExpr: 'data'),
        contains('if let codePoint = data.weather?.mood,'),
      );
    });

    test('boxes the glyph the way Android sizes it', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons, size: 40)
            .toSwift(0, dataExpr: 'data'),
        contains('.frame(width: 40, height: 40)'),
      );
      expect(
        const HWIcon(_mood, size: 40).toSwift(0, dataExpr: 'data'),
        contains('.frame(width: 40, height: 40)'),
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
        '    .frame(width: 24, height: 24)\n'
        '    .foregroundColor(Color.primary)\n'
        '    .accessibilityHidden(true)\n'
        '    .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)',
      );
    });

    test('asks the widget-wide set whether a bound glyph mirrors', () {
      expect(
        const HWIcon(_arrows).toSwift(0, dataExpr: 'data'),
        'if let codePoint = data.arrow, '
        'let value = UInt32(exactly: codePoint), '
        'let scalar = UnicodeScalar(value) {\n'
        '    Text(String(scalar))\n'
        '        .font(hwBundledFont("hw_font_icons_materialicons", size: 24))\n'
        '        .frame(width: 24, height: 24)\n'
        '        .foregroundColor(Color.primary)\n'
        '        .accessibilityHidden(true)\n'
        '        .scaleEffect(x: layoutDirection == .rightToLeft && '
        'hwMirroredIcons.contains(codePoint) ? -1 : 1, y: 1)\n'
        '}',
      );
      expect(
        const HWIcon(_mood).toSwift(0, dataExpr: 'data'),
        contains('hwMirroredIcons.contains(codePoint)'),
      );
    });

    test('leaves an undirectional constant glyph alone', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toSwift(0, dataExpr: 'data'),
        isNot(contains('scaleEffect')),
      );
    });

    test('declares the layout direction only where it reads it', () {
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
        const HWIcon(_mood).swiftViewModifiers,
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
        const HWIcon.resolvedGlyph(
          0xE88A,
          font: _materialIcons,
          fontResourcePrefix: 'hw_font_forecast',
        ).toKotlin(0, dataExpr: 'data'),
        'Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, '
        'R.font.hw_font_forecast__icons_materialicons, 0xE88A, 24f)), '
        'contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))',
      );
    });

    test('renders a bound glyph and skips a widget with no value', () {
      expect(
        const HWIcon.resolved(
          _mood,
          size: 32,
          semanticLabel: 'Mood',
          fontResourcePrefix: 'hw_font_forecast',
        ).toKotlin(0, dataExpr: 'data'),
        'data.mood?.let { codePoint ->\n'
        '    Image(modifier = GlanceModifier.size(32.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap('
        'context, R.font.hw_font_forecast__icons_materialicons, codePoint, '
        '32f, matchTextDirection = codePoint in hwMirroredIcons)), '
        'contentDescription = "Mood", '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))\n'
        '}',
      );
    });

    test('mirrors a directional constant glyph', () {
      expect(
        const HWIcon.resolvedGlyph(
          0xE5C4,
          font: _materialIcons,
          matchTextDirection: true,
          fontResourcePrefix: 'hw_font_forecast',
        ).toKotlin(0, dataExpr: 'data'),
        'Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap(context, '
        'R.font.hw_font_forecast__icons_materialicons, 0xE5C4, 24f, '
        'matchTextDirection = true)), '
        'contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))',
      );
    });

    test('asks the widget-wide set whether a bound glyph mirrors', () {
      expect(
        const HWIcon.resolved(_arrows, fontResourcePrefix: 'hw_font_forecast')
            .toKotlin(0, dataExpr: 'data'),
        'data.arrow?.let { codePoint ->\n'
        '    Image(modifier = GlanceModifier.size(24.dp), '
        'provider = ImageProvider(HomeWidgetFonts.iconBitmap('
        'context, R.font.hw_font_forecast__icons_materialicons, codePoint, '
        '24f, matchTextDirection = codePoint in hwMirroredIcons)), '
        'contentDescription = null, '
        'colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface))\n'
        '}',
      );
      expect(
        const HWIcon(_mood).toKotlin(0, dataExpr: 'data'),
        contains('matchTextDirection = codePoint in hwMirroredIcons'),
      );
    });

    test('leaves the argument out for an undirectional constant glyph', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toKotlin(0, dataExpr: 'data'),
        isNot(contains('matchTextDirection')),
      );
    });

    test('falls back to a widget-less font resource', () {
      expect(
        const HWIcon.glyph(0xE88A, font: _materialIcons)
            .toKotlin(0, dataExpr: 'data'),
        contains('R.font.hw_font_home_widget__icons_materialicons'),
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
