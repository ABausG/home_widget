import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

/// The Glance renderer [style] emits on Android, or null when it emits a
/// bitmap instead.
HWGlanceTextRenderer? _glanceRendererOf(HWTextStyle style) {
  final renderer = style.kotlinRenderer();
  return renderer is HWGlanceTextRenderer ? renderer : null;
}

void main() {
  group('HWAndroidFont', () {
    test('names the families Glance knows', () {
      expect(HWAndroidFont.serif.family, 'serif');
      expect(HWAndroidFont.sansSerif.family, 'sans-serif');
      expect(HWAndroidFont.monospace.family, 'monospace');
      expect(HWAndroidFont.cursive.family, 'cursive');
      expect(const HWAndroidFont.family('casual').family, 'casual');
    });

    test('only the custom choice renders the style own family', () {
      expect(HWAndroidFont.custom.isCustom, isTrue);
      expect(HWAndroidFont.custom.family, isNull);
      expect(HWAndroidFont.system.isCustom, isFalse);
      expect(HWAndroidFont.system.family, isNull);
      expect(HWAndroidFont.serif.isCustom, isFalse);
    });

    test('two choices are equal when they name the same font', () {
      expect(HWAndroidFont.serif, const HWAndroidFont.family('serif'));
      expect(
        HWAndroidFont.serif.hashCode,
        const HWAndroidFont.family('serif').hashCode,
      );
      expect(HWAndroidFont.serif, isNot(HWAndroidFont.monospace));
      expect(HWAndroidFont.system, isNot(HWAndroidFont.custom));
      expect(HWAndroidFont.system, isNot(HWAndroidFont.serif));
    });

    test('spells itself out the way it is written', () {
      expect('${HWAndroidFont.custom}', 'HWAndroidFont.custom');
      expect('${HWAndroidFont.system}', 'HWAndroidFont.system');
      expect('${HWAndroidFont.monospace}', 'HWAndroidFont.family(monospace)');
    });
  });

  group('resolving androidFont', () {
    test('inherits the choice of the style below it', () {
      const base = HWTextStyle(androidFont: HWAndroidFont.serif);
      const style = HWTextStyle(fontSize: 12, baseStyle: base);
      expect(_glanceRendererOf(style)?.fontFamily, 'serif');
    });

    test('a choice of its own wins over the one below it', () {
      const base = HWTextStyle(androidFont: HWAndroidFont.serif);
      const style = HWTextStyle(
        androidFont: HWAndroidFont.monospace,
        baseStyle: base,
      );
      expect(_glanceRendererOf(style)?.fontFamily, 'monospace');
    });

    test('a family of its own drops the choice of the style below it', () {
      const base = HWTextStyle(
        fontFamily: 'Chewy',
        androidFont: HWAndroidFont.system,
      );
      const style = HWTextStyle(fontFamily: 'Roboto Mono', baseStyle: base);
      expect(style.kotlinRenderer(), isA<HWBitmapTextRenderer>());
    });

    test('a role style carries the choice it declares itself', () {
      const style = HWRoleTextStyle.caption(
        fontFamily: 'Chewy',
        androidFont: HWAndroidFont.serif,
      );
      final renderer = _glanceRendererOf(style);
      expect(renderer?.fontFamily, 'serif');
      expect(renderer?.fontSize, 12.0);
    });

    test('a role style below hands its choice up', () {
      const base = HWRoleTextStyle.body(androidFont: HWAndroidFont.cursive);
      const style = HWTextStyle(italic: true, baseStyle: base);
      expect(_glanceRendererOf(style)?.fontFamily, 'cursive');
    });
  });

  group('picking the Android renderer', () {
    test('a family draws into a bitmap when nothing says otherwise', () {
      expect(
        const HWTextStyle(fontFamily: 'Chewy').kotlinRenderer(),
        isA<HWBitmapTextRenderer>(),
      );
    });

    test('the platform font renders as a plain Glance Text', () {
      const style = HWTextStyle(
        fontFamily: 'Chewy',
        androidFont: HWAndroidFont.system,
      );
      final renderer = _glanceRendererOf(style);
      expect(renderer, isNotNull);
      expect(renderer!.fontFamily, isNull);

      final imports = const HWText.fixed('Hi', style: style).kotlinImports;
      expect(imports, contains('import androidx.glance.text.Text'));
      expect(
        imports,
        isNot(contains('import androidx.glance.text.FontFamily')),
      );
      expect(imports, isNot(contains('import android.graphics.Typeface')));
    });

    test('a system family renders as a Glance Text naming it', () {
      const style = HWTextStyle(
        fontFamily: 'Chewy',
        fontSize: 14,
        androidFont: HWAndroidFont.serif,
      );
      const text = HWText.fixed('Hi', style: style);

      expect(
        text.toKotlin(0, dataExpr: 'data'),
        contains('fontFamily = FontFamily("serif")'),
      );
      expect(
        text.kotlinImports,
        containsAll(<String>[
          'import androidx.glance.text.Text',
          'import androidx.glance.text.FontFamily',
        ]),
      );
      expect(
        text.kotlinImports,
        isNot(contains('import es.antonborri.home_widget.HomeWidgetFonts')),
      );
    });

    test('only a baseline row pulls the typeface import in', () {
      const serif = HWText.fixed(
        'Hi',
        style: HWTextStyle(
          fontSize: 11,
          androidFont: HWAndroidFont.serif,
        ),
      );
      const bitmap = HWText.fixed(
        'There',
        style: HWTextStyle(fontFamily: 'Chewy', fontSize: 20),
      );
      const typeface = 'import android.graphics.Typeface';

      expect(serif.kotlinImports, isNot(contains(typeface)));
      expect(serif.kotlinBaselineText()!.kotlinImports, contains(typeface));

      expect(
        const HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          children: [bitmap, serif],
        ).kotlinImports,
        contains(typeface),
      );
      expect(
        const HWRow(children: [bitmap, serif]).kotlinImports,
        isNot(contains(typeface)),
      );
    });

    test('the custom choice without a family renders as a Glance Text', () {
      const style = HWTextStyle(androidFont: HWAndroidFont.custom);
      expect(style.kotlinRenderer(), isA<HWGlanceTextRenderer>());
      expect(_glanceRendererOf(style)?.fontFamily, isNull);
    });

    test('any system family name reaches the generated literal', () {
      const style = HWTextStyle(
        androidFont: HWAndroidFont.family('sans-serif-condensed'),
      );
      expect(
        const HWText.fixed('Hi', style: style).toKotlin(0, dataExpr: 'data'),
        contains('fontFamily = FontFamily("sans-serif-condensed")'),
      );
    });

    test('the style own TextStyle names the family too', () {
      const style = HWTextStyle(androidFont: HWAndroidFont.monospace);
      expect(
        style.toKotlin(0, dataExpr: 'data'),
        contains('fontFamily = FontFamily("monospace")'),
      );
      expect(
        style.kotlinImports,
        contains('import androidx.glance.text.FontFamily'),
      );
    });

    test('iOS still renders the family the style names', () {
      const style = HWTextStyle(
        fontFamily: 'Chewy',
        fontSize: 14,
        androidFont: HWAndroidFont.system,
      );
      expect(
        style.fontVariant,
        const HWFontVariant(family: 'Chewy', weight: 400, italic: false),
      );
      expect(
        const HWText.fixed('Hi', style: style).toSwift(0, dataExpr: 'data'),
        contains('hwFont("Chewy", 400, false, 14)'),
      );
    });
  });

  group('the baseline of a Glance text in a system family', () {
    String ascentOf(HWTextStyle style) =>
        style.kotlinRenderer().kotlinBaselineText.ascent('data');

    test('measures the typeface Glance itself renders with', () {
      expect(
        ascentOf(const HWTextStyle(androidFont: HWAndroidFont.serif)),
        contains('Typeface.create("serif", Typeface.NORMAL)'),
      );
    });

    test('follows Glance in drawing a medium weight bold', () {
      expect(
        ascentOf(
          const HWTextStyle(
            fontWeight: HWFontWeight.w500,
            androidFont: HWAndroidFont.serif,
          ),
        ),
        contains('Typeface.create("serif", Typeface.BOLD)'),
      );
      expect(
        ascentOf(
          const HWTextStyle(
            fontWeight: HWFontWeight.bold,
            androidFont: HWAndroidFont.serif,
          ),
        ),
        contains('Typeface.create("serif", Typeface.BOLD)'),
      );
    });

    test('carries the slant into the typeface', () {
      expect(
        ascentOf(
          const HWTextStyle(italic: true, androidFont: HWAndroidFont.serif),
        ),
        contains('Typeface.create("serif", Typeface.ITALIC)'),
      );
      expect(
        ascentOf(
          const HWTextStyle(
            italic: true,
            fontWeight: HWFontWeight.bold,
            androidFont: HWAndroidFont.serif,
          ),
        ),
        contains('Typeface.create("serif", Typeface.BOLD_ITALIC)'),
      );
    });

    test('keeps the weight and slant it hands the helper', () {
      expect(
        ascentOf(
          const HWTextStyle(
            fontSize: 14,
            fontWeight: HWFontWeight.bold,
            androidFont: HWAndroidFont.serif,
          ),
        ),
        'HomeWidgetFonts.textAscentPx(context, '
        'Typeface.create("serif", Typeface.BOLD), 14f, '
        'weight = 700, italic = false)',
      );
    });

    test('leaves the platform font for the helper to resolve', () {
      expect(
        ascentOf(const HWTextStyle(androidFont: HWAndroidFont.system)),
        contains('textAscentPx(context, null,'),
      );
    });

    test('is still a text the row can line up by', () {
      const text = HWText.fixed(
        'Hi',
        style: HWTextStyle(
          fontFamily: 'Chewy',
          androidFont: HWAndroidFont.serif,
        ),
      );
      expect(text.kotlinReportsBaseline, isTrue);
      expect(text.kotlinBaselineText()!.isBitmap, isFalse);
    });
  });

  group('rendersAndroidBitmapText', () {
    test('is true for a tree drawing text in a custom family', () {
      expect(
        const HWColumn(
          children: [
            HWText.fixed('Hi', style: HWTextStyle(fontFamily: 'Chewy')),
          ],
        ).rendersAndroidBitmapText,
        isTrue,
      );
    });

    test('is false when that text opts out of the bitmap', () {
      const tree = HWColumn(
        children: [
          HWText.fixed(
            'Hi',
            style: HWTextStyle(
              fontFamily: 'Chewy',
              androidFont: HWAndroidFont.system,
            ),
          ),
        ],
      );
      expect(tree.rendersAndroidBitmapText, isFalse);
      expect(tree.fontVariants, isNotEmpty);
    });

    test('is false for a tree in a system family only', () {
      expect(
        const HWColumn(
          children: [
            HWText.fixed(
              'Hi',
              style: HWTextStyle(androidFont: HWAndroidFont.monospace),
            ),
          ],
        ).rendersAndroidBitmapText,
        isFalse,
      );
    });

    test('is true when one text of several still draws a bitmap', () {
      expect(
        const HWColumn(
          children: [
            HWText.fixed(
              'Hi',
              style: HWTextStyle(
                fontFamily: 'Chewy',
                androidFont: HWAndroidFont.serif,
              ),
            ),
            HWText.fixed('There', style: HWTextStyle(fontFamily: 'Chewy')),
          ],
        ).rendersAndroidBitmapText,
        isTrue,
      );
    });

    test('is false for a tree with no text at all', () {
      expect(const HWColumn(children: []).rendersAndroidBitmapText, isFalse);
    });

    test('ignores the branch of an HWAdaptive only iOS renders', () {
      expect(
        const HWAdaptive(
          ios: HWText.fixed('Hi', style: HWTextStyle(fontFamily: 'Chewy')),
          android: HWText.fixed('Hi'),
        ).rendersAndroidBitmapText,
        isFalse,
      );
    });

    test('is true for a bitmap text in the branch Android renders', () {
      expect(
        const HWAdaptive(
          ios: HWText.fixed('Hi'),
          android: HWText.fixed('Hi', style: HWTextStyle(fontFamily: 'Chewy')),
        ).rendersAndroidBitmapText,
        isTrue,
      );
    });

    test('reaches a bitmap text nested in the Android branch', () {
      expect(
        const HWAdaptive(
          ios: HWText.fixed('Hi'),
          android: HWColumn(
            children: [
              HWText.fixed('Hi', style: HWTextStyle(fontFamily: 'Chewy')),
            ],
          ),
        ).rendersAndroidBitmapText,
        isTrue,
      );
    });
  });
}
