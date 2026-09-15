import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/utils/inject_glance_modifier.dart';
import 'package:test/test.dart';

void main() {
  group('HWTextStyle with a font family', () {
    test('resolves the family, package and file choice', () {
      const style = HWTextStyle(
        fontFamily: 'Chewy',
        package: 'my_fonts',
        fontWeight: HWFontWeight.bold,
        italic: true,
      );
      expect(
        style.fontVariant,
        const HWFontVariant(
          family: 'Chewy',
          package: 'my_fonts',
          weight: 700,
          italic: true,
        ),
      );
    });

    test('takes the package of the style that names it', () {
      const base = HWTextStyle(fontFamily: 'Chewy');
      expect(
        const HWTextStyle(package: 'my_fonts', baseStyle: base).fontVariant,
        const HWFontVariant(
          family: 'Chewy',
          package: 'my_fonts',
          weight: 400,
          italic: false,
        ),
      );
    });

    test('a family of its own drops the package of the style below it', () {
      const base = HWTextStyle(fontFamily: 'Chewy', package: 'my_fonts');
      expect(
        const HWTextStyle(fontFamily: 'Roboto Mono', baseStyle: base)
            .fontVariant,
        const HWFontVariant(
          family: 'Roboto Mono',
          weight: 400,
          italic: false,
        ),
      );
    });

    test('renders in the regular file when nothing sets a weight', () {
      expect(
        const HWTextStyle(fontFamily: 'Chewy').fontVariant,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
      );
    });

    test('maps every weight onto the 100..900 scale', () {
      const expected = {
        HWFontWeight.w100: 100,
        HWFontWeight.w200: 200,
        HWFontWeight.w300: 300,
        HWFontWeight.w400: 400,
        HWFontWeight.w500: 500,
        HWFontWeight.w600: 600,
        HWFontWeight.w700: 700,
        HWFontWeight.w800: 800,
        HWFontWeight.w900: 900,
        HWFontWeight.normal: 400,
        HWFontWeight.bold: 700,
      };
      for (final entry in expected.entries) {
        expect(
          HWTextStyle(fontFamily: 'Chewy', fontWeight: entry.key)
              .fontVariant
              ?.weight,
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('has no variant without a family', () {
      expect(const HWTextStyle(fontSize: 12).fontVariant, isNull);
    });

    test('inherits the family through baseStyle', () {
      const style = HWTextStyle(
        color: HWFixedColor(0xFF000000),
        baseStyle: HWTextStyle(fontFamily: 'Chewy', fontSize: 20),
      );
      expect(
        style.fontVariant,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
      );
      expect(style.effectiveFontSize, 20);
      expect(style.effectiveColor, const HWFixedColor(0xFF000000));
    });

    test('overriding the family drops the base style package', () {
      const style = HWTextStyle(
        fontFamily: 'Chewy',
        baseStyle: HWTextStyle(fontFamily: 'Roboto', package: 'my_fonts'),
      );
      expect(style.fontVariant?.family, 'Chewy');
      expect(style.fontVariant?.package, isNull);
    });

    test('takes the weight and the size of the role it is based on', () {
      const style = HWTextStyle(
        fontFamily: 'Chewy',
        baseStyle: HWRoleTextStyle.headline(),
      );
      expect(style.fontVariant?.weight, 600);
      expect(style.effectiveFontSize, 18);
    });

    test('a role style carries the family it declares itself', () {
      const style = HWRoleTextStyle.title(fontFamily: 'Chewy');
      expect(
        style.fontVariant,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
      );
      expect(style.effectiveFontSize, 22);
    });

    test('falls back to the default size when nothing sets one', () {
      expect(const HWTextStyle(fontFamily: 'Chewy').effectiveFontSize, isNull);
      expect(
        const HWTextStyle(fontFamily: 'Chewy').effectiveFontSizeOrDefault,
        hwDefaultFontSize,
      );
      expect(
        const HWRoleTextStyle.caption(fontFamily: 'Chewy')
            .effectiveFontSizeOrDefault,
        12,
      );
    });
  });

  group('HWText in a custom font', () {
    const style = HWTextStyle(fontFamily: 'Chewy', fontSize: 16);

    test('iOS calls the generated font switch instead of .system', () {
      expect(
        const HWText.fixed('Hello', style: style).toSwift(0, dataExpr: 'data'),
        'Text("Hello")\n'
        '    .font(hwFont("Chewy", 400, false, 16))',
      );
    });

    test('iOS bakes weight and slant into the file rather than the view', () {
      final swift = const HWText.fixed(
        'Hello',
        style: HWTextStyle(
          fontFamily: 'Chewy',
          fontWeight: HWFontWeight.bold,
          italic: true,
          underline: true,
          color: HWDefaultColor(HWColorRole.contentSecondary),
        ),
      ).toSwift(0, dataExpr: 'data');

      expect(swift, contains('.font(hwFont("Chewy", 700, true, 16))'));
      expect(swift, contains('.foregroundColor(Color.secondary)'));
      expect(swift, contains('.underline(true)'));
      expect(swift, isNot(contains('.italic()')));
      expect(swift, isNot(contains('.fontWeight(')));
    });

    test('iOS namespaces a package family the way Flutter does', () {
      expect(
        const HWText.fixed(
          'Hello',
          style: HWTextStyle(fontFamily: 'Chewy', package: 'my_fonts'),
        ).toSwift(0, dataExpr: 'data'),
        contains('.font(hwFont("packages/my_fonts/Chewy", 400, false, 16))'),
      );
    });

    test('Android draws the glyphs into a tinted bitmap', () {
      expect(
        const HWText.fixed('Hello', style: style).toKotlin(0, dataExpr: 'data'),
        'Image(\n'
        '    modifier = GlanceModifier,\n'
        '    provider = ImageProvider(\n'
        '        if (textBounds.isProbe("ccaec139", LocalSize.current)) '
        'HomeWidgetFonts.probeBitmap()\n'
        '        else HomeWidgetFonts.textBitmap(\n'
        '            context,\n'
        '            HomeWidgetFonts.typeface(context, "Chewy", 400, false),\n'
        '            "Hello",\n'
        '            fontSizeSp = 16f,\n'
        '            maxWidthDp = '
        'textBounds.width("ccaec139", LocalSize.current),\n'
        '            maxHeightDp = '
        'textBounds.height("ccaec139", LocalSize.current),\n'
        '        )\n'
        '    ),\n'
        '    contentDescription = if (textBounds.isProbe("ccaec139", '
        'LocalSize.current)) "hw_text_bounds:ccaec139" else "Hello",\n'
        '    colorFilter = ColorFilter.tint(GlanceTheme.colors.onSurface),\n'
        ')',
      );
    });

    test('Android carries slant, decorations, alignment and colour', () {
      expect(
        const HWText.fixed(
          'Hello',
          textAlign: HWTextAlign.center,
          style: HWTextStyle(
            fontFamily: 'Chewy',
            fontWeight: HWFontWeight.bold,
            italic: true,
            underline: true,
            lineThrough: true,
            color: HWFixedColor(0xFFFF0000),
          ),
        ).toKotlin(0, dataExpr: 'data'),
        'Image(\n'
        '    modifier = GlanceModifier,\n'
        '    provider = ImageProvider(\n'
        '        if (textBounds.isProbe("74c42a52", LocalSize.current)) '
        'HomeWidgetFonts.probeBitmap()\n'
        '        else HomeWidgetFonts.textBitmap(\n'
        '            context,\n'
        '            HomeWidgetFonts.typeface(context, "Chewy", 700, true),\n'
        '            "Hello",\n'
        '            fontSizeSp = 16f,\n'
        '            underline = true,\n'
        '            lineThrough = true,\n'
        '            textAlign = TextAlign.Center,\n'
        '            maxWidthDp = '
        'textBounds.width("74c42a52", LocalSize.current),\n'
        '            maxHeightDp = '
        'textBounds.height("74c42a52", LocalSize.current),\n'
        '            fillWidth = true,\n'
        '        )\n'
        '    ),\n'
        '    contentDescription = if (textBounds.isProbe("74c42a52", '
        'LocalSize.current)) "hw_text_bounds:74c42a52" else "Hello",\n'
        '    colorFilter = ColorFilter.tint(ColorProvider(day = '
        'Color(0xFFFF0000), night = Color(0xFFFF0000))),\n'
        ')',
      );
    });

    test('the slant only picks the file', () {
      const italic = HWTextStyle(fontFamily: 'Chewy', italic: true);
      final kotlin =
          const HWText.fixed('Hello', style: italic).toKotlin(0, dataExpr: 'd');
      expect(
        kotlin,
        contains('HomeWidgetFonts.typeface(context, "Chewy", 400, true)'),
      );
      expect(kotlin, isNot(contains('italic')));
    });

    test('Android reads a bound value the way a Glance Text would', () {
      final kotlin = const HWText(HWString('title'), style: style)
          .toKotlin(0, dataExpr: 'data');
      expect(kotlin, contains('            data.title ?: "",\n'));
      expect(
        kotlin,
        contains(
          'contentDescription = if (textBounds.isProbe("b983ed84", '
          'LocalSize.current)) "hw_text_bounds:b983ed84" else data.title ?: "",',
        ),
      );
    });

    test('Android keeps the indentation of its level', () {
      expect(
        const HWText.fixed('Hello', style: style).toKotlin(2, dataExpr: 'data'),
        startsWith('        Image(\n            modifier = GlanceModifier,'),
      );
    });

    test('imports the bitmap image instead of the Glance text', () {
      final imports = const HWText.fixed(
        'Hello',
        textAlign: HWTextAlign.center,
        style: style,
      ).kotlinImports;

      expect(
        imports,
        containsAll(<String>[
          'import androidx.glance.ColorFilter',
          'import androidx.glance.GlanceModifier',
          'import androidx.glance.GlanceTheme',
          'import androidx.glance.Image',
          'import androidx.glance.ImageProvider',
          'import androidx.glance.LocalSize',
          'import androidx.glance.text.TextAlign',
          'import es.antonborri.home_widget.HomeWidgetFonts',
        ]),
      );
      expect(imports, isNot(contains('import androidx.glance.text.Text')));
      expect(imports, isNot(contains('import androidx.glance.text.TextStyle')));
      expect(imports, isNot(contains('import androidx.compose.ui.unit.sp')));
      expect(
        imports,
        isNot(contains('import androidx.glance.text.FontWeight')),
      );
    });

    test('the style imports what its own TextStyle emits, not the bitmap', () {
      expect(style.toKotlin(0, dataExpr: 'data'), startsWith('TextStyle('));
      expect(
        style.kotlinImports,
        containsAll(<String>[
          'import androidx.glance.text.Text',
          'import androidx.glance.text.TextStyle',
          'import androidx.compose.ui.unit.sp',
        ]),
      );
      expect(
        style.kotlinImports,
        isNot(contains('import es.antonborri.home_widget.HomeWidgetFonts')),
      );
    });

    test('leaves out the text alignment import when nothing aligns', () {
      expect(
        const HWText.fixed('Hello', style: style).kotlinImports,
        isNot(contains('import androidx.glance.text.TextAlign')),
      );
    });

    test('takes an injected modifier onto its own', () {
      final injected = injectGlanceModifier(
        const HWText(HWString('title'), style: style)
            .toKotlin(0, dataExpr: 'data'),
        'padding(4.dp)',
      );

      expect(
        injected,
        startsWith(
          'Image(\n    modifier = GlanceModifier.padding(4.dp),\n',
        ),
      );
      expect(injected, endsWith('\n)'));
      expect(injected, contains('HomeWidgetFonts.textBitmap('));
      expect(
        'GlanceModifier'.allMatches(injected).length,
        1,
        reason: 'the injected modifier must not add a second one',
      );
    });

    test('takes an injected modifier at depth', () {
      expect(
        injectGlanceModifier(
          const HWText.fixed('Hello', style: style).toKotlin(2, dataExpr: 'd'),
          'fillMaxWidth()',
        ),
        startsWith(
          '        Image(\n'
          '            modifier = GlanceModifier.fillMaxWidth(),\n',
        ),
      );
    });

    test('a text in the platform font is untouched', () {
      const plain = HWText.fixed('Hello', style: HWTextStyle(fontSize: 16));
      expect(
        plain.toKotlin(0, dataExpr: 'data'),
        'Text(text = "Hello", style = TextStyle('
        'color = GlanceTheme.colors.onSurface, fontSize = 16.sp))',
      );
      expect(
        plain.kotlinImports,
        containsAll(<String>[
          'import androidx.glance.text.Text',
          'import androidx.glance.text.TextStyle',
        ]),
      );
      expect(plain.fontVariant, isNull);
    });
  });

  group('the room a bitmap text is drawn in', () {
    const style = HWTextStyle(fontFamily: 'Chewy', fontSize: 16);
    const text = HWText.fixed('Hello', style: style);

    test('is looked up under one key against the size composed against', () {
      final kotlin = text.toKotlin(0, dataExpr: 'data');
      final key = RegExp(r'textBounds\.width\("([0-9a-f]{8})"')
          .firstMatch(kotlin)
          ?.group(1);

      expect(key, isNotNull);
      expect(
        kotlin,
        contains('maxWidthDp = textBounds.width("$key", LocalSize.current),'),
      );
      expect(
        kotlin,
        contains('maxHeightDp = textBounds.height("$key", LocalSize.current),'),
      );
    });

    test('is measured by a probe carrying the same key', () {
      final kotlin = text.toKotlin(0, dataExpr: 'data');
      final key = RegExp(r'textBounds\.width\("([0-9a-f]{8})"')
          .firstMatch(kotlin)!
          .group(1);

      expect(
        kotlin,
        contains(
          '        if (textBounds.isProbe("$key", LocalSize.current)) '
          'HomeWidgetFonts.probeBitmap()\n'
          '        else HomeWidgetFonts.textBitmap(',
        ),
      );
      expect(
        kotlin,
        contains(
          'contentDescription = if (textBounds.isProbe("$key", '
          'LocalSize.current)) "hw_text_bounds:$key" else "Hello",',
        ),
      );
    });

    test('is asked for by what the padding around it wraps', () {
      const padded = HWPadding(
        child: text,
        padding: HWEdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

      final kotlin = padded.toKotlin(0, dataExpr: 'data');
      expect(
        kotlin,
        startsWith(
          'Image(\n'
          '    modifier = GlanceModifier.padding(start = 12.0.dp, top = 8.0.dp,'
          ' end = 12.0.dp, bottom = 8.0.dp),\n',
        ),
      );
      expect(kotlin, contains('textBounds.width('));
      expect(kotlin, isNot(contains('LocalSize.current.width.value')));
    });

    test('is keyed apart from the room another text asks for', () {
      const other = HWText.fixed('Goodbye', style: style);

      expect(
        _boundsKeysIn(text.toKotlin(0, dataExpr: 'data')),
        isNot(_boundsKeysIn(other.toKotlin(0, dataExpr: 'data'))),
      );
    });

    test('is shared by two texts drawn exactly alike', () {
      const row = HWRow(children: [text, text]);
      final keys = _boundsKeysIn(row.toKotlin(0, dataExpr: 'data'));

      expect(keys, hasLength(1));
      expect(keys, _boundsKeysIn(text.toKotlin(0, dataExpr: 'data')));
    });

    test('tells the size and the decorations of a text apart', () {
      const keyed = <String, HWText>{
        'plain': HWText.fixed('Hello', style: style),
        'larger': HWText.fixed(
          'Hello',
          style: HWTextStyle(fontFamily: 'Chewy', fontSize: 24),
        ),
        'other family': HWText.fixed(
          'Hello',
          style: HWTextStyle(fontFamily: 'Roboto Mono', fontSize: 16),
        ),
        'packaged': HWText.fixed(
          'Hello',
          style: HWTextStyle(
            fontFamily: 'Chewy',
            package: 'my_fonts',
            fontSize: 16,
          ),
        ),
        'bold': HWText.fixed(
          'Hello',
          style: HWTextStyle(
            fontFamily: 'Chewy',
            fontSize: 16,
            fontWeight: HWFontWeight.bold,
          ),
        ),
        'italic': HWText.fixed(
          'Hello',
          style: HWTextStyle(
            fontFamily: 'Chewy',
            fontSize: 16,
            italic: true,
          ),
        ),
        'underlined': HWText.fixed(
          'Hello',
          style: HWTextStyle(
            fontFamily: 'Chewy',
            fontSize: 16,
            underline: true,
          ),
        ),
        'struck through': HWText.fixed(
          'Hello',
          style: HWTextStyle(
            fontFamily: 'Chewy',
            fontSize: 16,
            lineThrough: true,
          ),
        ),
        'centered': HWText.fixed(
          'Hello',
          style: style,
          textAlign: HWTextAlign.center,
        ),
      };

      final keys = <String, String>{
        for (final entry in keyed.entries)
          entry.key:
              _boundsKeysIn(entry.value.toKotlin(0, dataExpr: 'd')).single,
      };

      expect(keys.values.toSet(), hasLength(keys.length), reason: '$keys');
    });

    test('is keyed by the expression the text is read out of, not its tint',
        () {
      const tinted = HWText.fixed(
        'Hello',
        style: HWTextStyle(
          fontFamily: 'Chewy',
          fontSize: 16,
          color: HWFixedColor(0xFFFF0000),
        ),
      );

      expect(
        _boundsKeysIn(tinted.toKotlin(0, dataExpr: 'data')),
        _boundsKeysIn(text.toKotlin(0, dataExpr: 'data')),
      );
      expect(
        _boundsKeysIn(
          const HWText(HWString('title'), style: style)
              .toKotlin(0, dataExpr: 'data'),
        ),
        isNot(_boundsKeysIn(text.toKotlin(0, dataExpr: 'data'))),
      );
    });
  });

  group('the alignment of a bitmap text', () {
    const style = HWTextStyle(fontFamily: 'Chewy', fontSize: 16);

    test('fills the width it has so an end aligned line can move', () {
      expect(
        const HWText.fixed('Hello', style: style, textAlign: HWTextAlign.end)
            .toKotlin(0, dataExpr: 'data'),
        contains('fillWidth = true,'),
      );
    });

    test('keeps the tight crop for a start aligned line', () {
      for (final align in [HWTextAlign.start, HWTextAlign.justify]) {
        expect(
          HWText.fixed('Hello', style: style, textAlign: align)
              .toKotlin(0, dataExpr: 'data'),
          isNot(contains('fillWidth')),
          reason: '$align',
        );
      }
      expect(
        const HWText.fixed('Hello', style: style).toKotlin(0, dataExpr: 'data'),
        isNot(contains('fillWidth')),
      );
    });
  });

  group('a family with characters the target languages read', () {
    const style = HWTextStyle(fontFamily: r'A "$weird" \name');

    test('is escaped into the Kotlin literal', () {
      expect(
        const HWText.fixed('Hi', style: style).toKotlin(0, dataExpr: 'data'),
        contains(
          r'HomeWidgetFonts.typeface(context, "A \"\$weird\" \\name", 400, '
          'false)',
        ),
      );
    });

    test('is escaped into the Swift literal', () {
      expect(
        const HWText.fixed('Hi', style: style).toSwift(0, dataExpr: 'data'),
        contains(r'hwFont("A \"$weird\" \\name", 400, false, 16)'),
      );
    });
  });

  group('native helpers', () {
    test('a custom family pulls in the family lookup and what it calls', () {
      const text = HWText.fixed(
        'Hello',
        style: HWTextStyle(fontFamily: 'Chewy'),
      );

      expect(text.renderHelpers, contains(HWNativeHelper.hwFont));
      expect(text.nativeHelpers, contains(HWNativeHelper.hwFont));
      expect(
        HWNativeHelper.hwFont.dependencies,
        contains(HWNativeHelper.hwAssetFont),
      );
      expect(
        HWNativeHelper.hwAssetFont.dependencies,
        contains(HWNativeHelper.hwFontFromURL),
      );
      expect(
        const HWColumn(children: [text]).nativeHelpers,
        contains(HWNativeHelper.hwFont),
      );
    });

    test('a text in the platform font pulls in none of them', () {
      const text = HWText.fixed('Hello');
      expect(text.nativeHelpers, isNot(contains(HWNativeHelper.hwFont)));
      expect(
        text.nativeHelpers,
        isNot(contains(HWNativeHelper.hwFontFromURL)),
      );
    });

    test('an icon pulls in the bundled font reader and its own', () {
      const icon = HWIcon.glyph(0xE88A, font: HWIconFont(family: 'Material'));

      expect(icon.renderHelpers, contains(HWNativeHelper.hwBundledFont));
      expect(
        const HWColumn(children: [icon]).nativeHelpers,
        contains(HWNativeHelper.hwBundledFont),
      );
      expect(
        HWNativeHelper.hwBundledFont.dependencies,
        contains(HWNativeHelper.hwFontFromURL),
      );
    });

    test('the font helpers are Swift only and locale independent', () {
      const helpers = [
        HWNativeHelper.hwFontFromURL,
        HWNativeHelper.hwAssetFont,
        HWNativeHelper.hwBundledFont,
        HWNativeHelper.hwFont,
      ];
      for (final helper in helpers) {
        expect(
          helper.toKotlin(0, dataExpr: 'data'),
          isEmpty,
          reason: helper.name,
        );
        expect(helper.kotlinImports, isEmpty, reason: helper.name);
        expect(
          helper.toSwift(0, dataExpr: 'data'),
          contains('func ${helper.name}('),
          reason: helper.name,
        );
        expect(helper.localeDependent, isFalse, reason: helper.name);
        expect(
          helper.swiftImports,
          contains('import SwiftUI'),
          reason: helper.name,
        );
      }
      expect(
        HWNativeHelper.hwFontFromURL.swiftImports,
        {'import CoreText', 'import SwiftUI'},
      );
      expect(
        HWNativeHelper.hwFontFromURL.toSwift(0, dataExpr: 'data'),
        isNot(contains('CTFontManagerRegisterFontsForURL')),
      );
    });
  });

  group('fontVariants', () {
    test('collects every file a tree renders with, once', () {
      const tree = HWColumn(
        children: [
          HWText.fixed('a', style: HWTextStyle(fontFamily: 'Chewy')),
          HWRow(
            children: [
              HWText.fixed('b', style: HWTextStyle(fontFamily: 'Chewy')),
              HWText.fixed(
                'c',
                style: HWTextStyle(
                  fontFamily: 'Chewy',
                  fontWeight: HWFontWeight.bold,
                ),
              ),
              HWText.fixed('d'),
            ],
          ),
        ],
      );

      expect(tree.fontVariants, {
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
        const HWFontVariant(family: 'Chewy', weight: 700, italic: false),
      });
    });

    test('is empty for a tree in the platform font', () {
      expect(
        const HWColumn(children: [HWText.fixed('a')]).fontVariants,
        isEmpty,
      );
    });

    test('reads the widgets carrying a font rather than the texts', () {
      const text = HWText.fixed('a', style: HWTextStyle(fontFamily: 'Chewy'));
      expect(text, isA<HWFontWidget>());
      expect(
        const HWIcon.glyph(0xE88A, font: HWIconFont(family: 'M')),
        isNot(isA<HWFontWidget>()),
      );

      const fake = _FakeFontWidget(
        HWFontVariant(family: 'Chewy', weight: 900, italic: true),
      );
      expect(
        <Object>[fake, text]
            .whereType<HWFontWidget>()
            .map((w) => w.fontVariant),
        [fake.fontVariant, text.fontVariant],
      );
    });
  });
}

/// Every key [kotlin] looks a measured text size up under.
Set<String> _boundsKeysIn(String kotlin) => RegExp(
      r'textBounds\.(?:width|height)\("([0-9a-f]{8})"',
    ).allMatches(kotlin).map((match) => match.group(1)!).toSet();

/// A widget-shaped thing rendering in a font of its own.
class _FakeFontWidget with HWFontWidget {
  @override
  final HWFontVariant? fontVariant;

  const _FakeFontWidget(this.fontVariant);
}
