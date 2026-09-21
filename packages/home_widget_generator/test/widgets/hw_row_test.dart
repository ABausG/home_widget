import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWRow', () {
    group('model', () {
      test('merges data dependencies from children', () {
        const row = HWRow(
          children: [
            HWText(HWString('a')),
            HWText(HWInt('b')),
          ],
        );
        expect(row.dataDependencies, hasLength(2));
        expect(
          row.dataDependencies,
          containsAll(<Object>[const HWString('a'), const HWInt('b')]),
        );
      });

      test('unions swiftViewModifiers from themed child', () {
        const row = HWRow(
          children: [
            HWText.fixed(
              'x',
              style: HWTextStyle(
                color: HWThemedColor(
                  light: HWFixedColor(0xFF000000),
                  dark: HWFixedColor(0xFFFFFFFF),
                ),
              ),
            ),
            HWText.fixed('y'),
          ],
        );
        expect(
          row.swiftViewModifiers.any(
            (e) => e.contains('colorScheme'),
          ),
          isTrue,
        );
      });

      test('const constructor', () {
        const row = HWRow(children: [HWText.fixed('x')]);
        expect(row, isA<HWRow>());
        expect(row, isA<HWWidget>());
        expect(row.children, hasLength(1));
      });

      test('Column in Row', () {
        const widget = HWRow(
          children: [
            HWColumn(children: [HWText.fixed('nested')]),
          ],
        );
        expect(widget.children.first, isA<HWColumn>());
      });

      test('mixed children (text and column)', () {
        const widget = HWRow(
          children: [
            HWText.fixed('a'),
            HWColumn(children: [HWText.fixed('b')]),
          ],
        );
        expect(widget.children[0], isA<HWText>());
        expect(widget.children[1], isA<HWColumn>());
      });
    });

    group('iOS (SwiftUI)', () {
      test('swiftFrameAlignment keeps the cross axis, never the main one', () {
        const children = [HWText.fixed('a')];
        expect(
          const HWRow(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.start,
            mainAxisAlignment: HWMainAxisAlignment.end,
          ).swiftFrameAlignment,
          '.topLeading',
        );
        expect(
          const HWRow(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.baseline,
          ).swiftFrameAlignment,
          '.topLeading',
        );
        expect(
          const HWRow(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.center,
          ).swiftFrameAlignment,
          '.leading',
        );
        expect(
          const HWRow(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.end,
          ).swiftFrameAlignment,
          '.bottomLeading',
        );
        expect(const HWRow(children: children).swiftFrameAlignment, '.leading');
      });

      test('HStack with children defaults to center', () {
        final node = HWRow(children: [HWText.fixed('x')]);
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center) {'));
        expect(r, contains('Text("x")'));
      });

      test('crossAxis .start → top', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .top) {'));
      });

      test('crossAxis .center → center', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center) {'));
      });

      test('crossAxis .end → bottom', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .bottom) {'));
      });

      test('crossAxis .baseline → firstTextBaseline', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .firstTextBaseline) {'));
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center) {'));
        expect(r, contains('Text("a")'));
        expect(r, contains('Spacer()'));
        expect(r, contains('Text("b")'));
        expect('Spacer()'.allMatches(r).length, 1);
      });

      test('mainAxis .center wraps with Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.center,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 2);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });

      test('mainAxis .end leads with Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.end,
          children: [HWText.fixed('a')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 1);
        expect(r, contains('Text("a")'));
      });

      test('mainAxis .spaceEvenly has Spacer between and around', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 3);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });
    });

    group('Android (Glance)', () {
      test('kotlinImports add Alignment and Spacer when set', () {
        final w = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
          mainAxisAlignment: HWMainAxisAlignment.end,
        );
        expect(w.kotlinImports, contains('import androidx.glance.layout.Row'));
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Alignment'),
        );
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Spacer'),
        );
      });

      test('kotlinImports include Row', () {
        final w = HWRow(children: [HWText.fixed('a')]);
        expect(w.kotlinImports, contains('import androidx.glance.layout.Row'));
      });

      test('Row with child defaults to CenterVertically', () {
        final node = HWRow(children: [HWText.fixed('x')]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Row(verticalAlignment = Alignment.CenterVertically) {'),
        );
        expect(r, contains('Text(text = "x",'));
      });

      test('crossAxis .start → Top', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row(verticalAlignment = Alignment.Top) {'));
      });

      test('crossAxis .end → Bottom', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row(verticalAlignment = Alignment.Bottom) {'));
      });

      test('crossAxis .baseline → Top, one text lining nothing up', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row(verticalAlignment = Alignment.Top) {'));
        expect(r, isNot(contains('run {')));
        expect(r, isNot(contains('hwAscent')));
        expect(
          node.kotlinImports,
          isNot(contains('import es.antonborri.home_widget.HomeWidgetFonts')),
        );
      });

      test('crossAxis .center → CenterVertically', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Row(verticalAlignment = Alignment.CenterVertically) {'),
        );
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Row(modifier = GlanceModifier.fillMaxWidth(), '
            'verticalAlignment = Alignment.CenterVertically) {',
          ),
        );
        expect(r, contains('Text(text = "a",'));
        expect(r, contains('Text(text = "b",'));
        expect(
          r,
          contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
        );
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          1,
        );
      });

      test('mainAxis .center wraps with weighted Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.center,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          2,
        );
        expect(r, contains('Text(text = "a",'));
        expect(r, contains('Text(text = "b",'));
      });

      test('mainAxis .end leads with weighted Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.end,
          children: [HWText.fixed('a')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          1,
        );
        expect(r, contains('Text(text = "a",'));
      });

      test('mainAxis .spaceEvenly with weighted Spacers', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          3,
        );
        expect(r, contains('Text(text = "a",'));
        expect(r, contains('Text(text = "b",'));
      });

      for (final alignment in [
        HWMainAxisAlignment.center,
        HWMainAxisAlignment.end,
        HWMainAxisAlignment.spaceBetween,
        HWMainAxisAlignment.spaceEvenly,
      ]) {
        test('mainAxis .${alignment.name} fills the width', () {
          final node = HWRow(
            children: [HWText.fixed('a'), HWText.fixed('b')],
            mainAxisAlignment: alignment,
          );
          expect(
            node.toKotlin(0, dataExpr: 'data'),
            contains('Row(modifier = GlanceModifier.fillMaxWidth(), '),
          );
          expect(
            node.kotlinImports,
            contains('import androidx.glance.layout.fillMaxWidth'),
          );
        });
      }

      test('mainAxis .start does not fill the width', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.start,
        );
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('fillMax')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );
      });

      test('no mainAxis alignment does not fill the width', () {
        final node = HWRow(children: [HWText.fixed('a')]);
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('fillMax')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );
      });

      test('a row in a row takes a weight rather than the width', () {
        const inner = HWRow(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWRow(children: [inner, HWText.fixed('b')]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Row(modifier = GlanceModifier.defaultWeight(), '),
        );
        expect(r, isNot(contains('fillMaxWidth')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );
      });

      test('a row in a column still fills the width', () {
        const inner = HWRow(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWColumn(children: [inner]);
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains('Row(modifier = GlanceModifier.fillMaxWidth(), '),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.fillMaxWidth'),
        );
      });
    });

    group('Android baseline defeat', () {
      for (final alignment in [
        HWCrossAxisAlignment.start,
        HWCrossAxisAlignment.end,
      ]) {
        test('crossAxis .${alignment.name} wraps a text child in a Box', () {
          final node = HWRow(
            children: [HWText.fixed('a')],
            crossAxisAlignment: alignment,
          );
          expect(
            node.toKotlin(0, dataExpr: 'data'),
            '''
Row(verticalAlignment = Alignment.${alignment == HWCrossAxisAlignment.start ? 'Top' : 'Bottom'}) {
    Box {
        Text(text = "a", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''',
          );
          expect(
            node.kotlinImports,
            contains('import androidx.glance.layout.Box'),
          );
        });
      }

      test('crossAxis .center leaves the baselines alone', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('Box {')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
        );
      });

      test('no alignment leaves the baselines alone', () {
        final node = HWRow(children: [HWText.fixed('a')]);
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('Box {')));
      });

      test('a non-text child is never wrapped', () {
        final node = HWRow(
          children: [
            HWImage(HWImageData('avatar'), width: 24),
            HWRow(children: [HWText.fixed('inner')]),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, isNot(contains('Box {')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
        );
      });

      test('a Spacer is never wrapped', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('Box {'.allMatches(r).length, 2);
        expect(
          r,
          contains('    Spacer(modifier = GlanceModifier.defaultWeight())'),
        );
      });

      test('text kept by a wrapper is still wrapped', () {
        final node = HWRow(
          children: [
            HWPadding(padding: HWEdgeInsets.all(4), child: HWText.fixed('a')),
            HWColoredBox(
              color: HWColor.fixed(0xFF00FF00),
              child: HWText.fixed('b'),
            ),
            HWDecoratedBox(
              decoration: HWBoxDecoration(color: HWColor.fixed(0xFF0000FF)),
              child: HWText.fixed('c'),
            ),
            HWDataExists(
              data: HWString('maybe'),
              whenPresent: HWText.fixed('d'),
              whenAbsent: HWImage(HWImageData('avatar'), width: 8),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('Box {'.allMatches(r).length, 4);
      });

      test('a widget that emits a Box of its own is not wrapped again', () {
        final node = HWRow(
          children: [
            HWDecoratedBox(
              decoration: HWBoxDecoration(
                border: HWBoxBorder(thickness: 1, color: HWColor.fixed(0)),
              ),
              child: HWText.fixed('a'),
            ),
            HWSizedBox.expand(child: HWText.fixed('b')),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, isNot(contains('Box {')));
      });

      test('an adaptive child is wrapped when its Android branch is text', () {
        final node = HWRow(
          children: [
            HWAdaptive(
              ios: HWImage(HWImageData('avatar'), width: 8),
              android: HWText.fixed('a'),
            ),
            HWAdaptive(
              ios: HWText.fixed('b'),
              android: HWImage(HWImageData('avatar'), width: 8),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('Box {'.allMatches(r).length, 1);
      });

      test('a size-adaptive child is wrapped when any slot is text', () {
        const textSlot = HWSizeAdaptive(
          small: HWText.fixed('a'),
          large: HWText.fixed('b'),
        );
        final imageSlot = HWSizeAdaptive(
          small: HWImage(HWImageData('avatar'), width: 8),
          large: HWImage(HWImageData('avatar'), width: 8),
        );
        expect(textSlot.kotlinReportsBaseline, isTrue);
        expect(imageSlot.kotlinReportsBaseline, isFalse);
        final node = HWRow(
          children: [textSlot, imageSlot],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('Box {'.allMatches(r).length, 1);
      });

      test('a bitmap text carries no baseline', () {
        const text = HWText.fixed(
          'a',
          style: HWTextStyle(fontFamily: 'Chewy', fontSize: 18),
        );
        expect(text.kotlinReportsBaseline, isFalse);
        final node = HWRow(
          children: [text],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('Box {')));
      });

      test('a wrapped child is laid out by the Box, not by the row', () {
        const node = HWRow(
          children: [
            HWSizeAdaptive(
              small: HWText.fixed('a'),
              large: HWRow(
                children: [HWText.fixed('b')],
                mainAxisAlignment: HWMainAxisAlignment.center,
              ),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Box {'));
        expect(r, contains('Row(modifier = GlanceModifier.fillMaxWidth(), '));
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.fillMaxWidth'),
        );
      });

      test('crossAxis .baseline leaves the baselines alone', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('Box')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
        );
      });
    });

    group('Android baseline alignment', () {
      test('two plain texts are left to the layout', () {
        final node = HWRow(
          children: [
            HWText.fixed('50', style: HWTextStyle(fontSize: 28)),
            HWText.fixed('Points'),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          '''
Row(verticalAlignment = Alignment.Top) {
    Text(text = "50", style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 28.sp))
    Text(text = "Points", style = TextStyle(color = GlanceTheme.colors.onSurface))
}''',
        );
        expect(
          node.kotlinImports,
          isNot(contains('import es.antonborri.home_widget.HomeWidgetFonts')),
        );
      });

      test('a bitmap text beside a plain one is padded to the baseline', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              '50',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
            HWText.fixed('Points', style: HWTextStyle(fontSize: 14)),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, startsWith('Row(verticalAlignment = Alignment.Top) {'));
        const ascents =
            'listOf(HomeWidgetFonts.textAscentPx(context, HomeWidgetFonts'
            '.typeface(context, "Chewy", 400, false), 28f), HomeWidgetFonts'
            '.textAscentPx(context, null, 14f, weight = 400, italic = false))';
        expect(
          r,
          contains(
            'Box(modifier = GlanceModifier.padding(top = HomeWidgetFonts'
            '.baselinePadding(context, $ascents, 0))) {',
          ),
        );
        expect(
          r,
          contains(
            'Box(modifier = GlanceModifier.padding(top = HomeWidgetFonts'
            '.baselinePadding(context, $ascents, 1))) {',
          ),
        );
      });

      test('two bitmap texts are both padded', () {
        const style = HWTextStyle(fontFamily: 'Chewy', fontSize: 28);
        final node = HWRow(
          children: [
            HWText.fixed('50', style: style),
            HWText.fixed('Points', style: style),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('HomeWidgetFonts.baselinePadding('.allMatches(r).length, 2);
      });

      test('a plain text with no size of its own is measured open', () {
        final node = HWRow(
          children: [
            HWText.fixed('a'),
            HWText.fixed(
              'b',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(
            'HomeWidgetFonts.textAscentPx(context, null, null, '
            'weight = 400, italic = false)',
          ),
        );
      });

      test('the ascent follows the style size, weight and slant', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(
                fontSize: 13.5,
                fontWeight: HWFontWeight.bold,
                italic: true,
              ),
            ),
            HWText.fixed(
              'b',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(
            'HomeWidgetFonts.textAscentPx(context, null, '
            '13.5f, weight = 700, italic = true)',
          ),
        );
      });

      test('a medium weight is measured at the weight Glance draws', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(fontSize: 12, fontWeight: HWFontWeight.w600),
            ),
            HWText.fixed(
              'b',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('fontWeight = FontWeight.Medium'));
        expect(
          r,
          contains(
            'HomeWidgetFonts.textAscentPx(context, null, 12f, '
            'weight = 500, italic = false)',
          ),
        );
      });

      test('one text beside a picture lines nothing up', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
            HWImage(HWImageData('avatar'), width: 8),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, isNot(contains('baselinePadding')));
        expect(r, contains('Row(verticalAlignment = Alignment.Top) {'));
      });

      test('a child rendering no text is left at the top', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
            HWIcon.resolvedGlyph(
              0xe800,
              font: HWIconFont(family: 'Fonts'),
              fontResourcePrefix: 'hw_font_demo',
            ),
            HWText.fixed('b'),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('HomeWidgetFonts.baselinePadding('.allMatches(r).length, 2);
        expect(r, contains('baselinePadding(context, listOf('));
        expect(r, isNot(contains('), 2)))')));
      });

      test('a text kept by a wrapper is what the row goes by', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              '50',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
            HWPadding(
              padding: HWEdgeInsets.only(left: 6),
              child: HWText.fixed('Points', style: HWTextStyle(fontSize: 14)),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains(
            'HomeWidgetFonts.textAscentPx(context, null, '
            '14f, weight = 400, italic = false)',
          ),
        );
      });

      test('room above a text keeps the row from lining it up', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              '50',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
            ),
            HWPadding(
              padding: HWEdgeInsets.only(top: 6),
              child: HWText.fixed('Points', style: HWTextStyle(fontSize: 14)),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          isNot(contains('baselinePadding')),
        );
      });

      test('the spacers of a main-axis alignment keep their place', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
            HWText.fixed('b'),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Row(modifier = GlanceModifier.fillMaxWidth(), '
            'verticalAlignment = Alignment.Top) {',
          ),
        );
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          2,
        );
        expect('HomeWidgetFonts.baselinePadding('.allMatches(r).length, 2);
      });

      test('imports what the padded boxes need', () {
        final node = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
            HWText.fixed('b'),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          node.kotlinImports,
          containsAll(<String>[
            'import androidx.glance.layout.Box',
            'import androidx.glance.layout.padding',
            'import es.antonborri.home_widget.HomeWidgetFonts',
          ]),
        );
      });

      test('a padded row still takes the modifiers put on it', () {
        const row = HWRow(
          children: [
            HWText.fixed(
              'a',
              style: HWTextStyle(fontFamily: 'Chewy', fontSize: 12),
            ),
            HWText.fixed('b'),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        expect(
          const HWSizedBox.expand(child: row).toKotlin(0, dataExpr: 'data'),
          startsWith(
            'Row(modifier = GlanceModifier.fillMaxSize(), '
            'verticalAlignment = Alignment.Top) {',
          ),
        );
        expect(
          HWPadding(padding: HWEdgeInsets.all(4), child: row)
              .toKotlin(0, dataExpr: 'data'),
          startsWith(
            'Row(modifier = GlanceModifier.padding(start = 4.0.dp, '
            'top = 4.0.dp, end = 4.0.dp, bottom = 4.0.dp), '
            'verticalAlignment = Alignment.Top) {',
          ),
        );
      });
    });

    group('kotlinBaselineText', () {
      test('a plain text answers with the size it renders at', () {
        const text = HWText.fixed('a', style: HWTextStyle(fontSize: 21));
        final baseline = text.kotlinBaselineText()!;
        expect(baseline.isBitmap, isFalse);
        expect(baseline.ascent('data'), contains('21f'));
      });

      test('a custom font text answers with its own typeface', () {
        const text = HWText.fixed(
          'a',
          style: HWTextStyle(fontFamily: 'Chewy', fontSize: 18),
        );
        final baseline = text.kotlinBaselineText()!;
        expect(baseline.isBitmap, isTrue);
        expect(
          baseline.ascent('data'),
          contains('HomeWidgetFonts.typeface(context, "Chewy", 400, false)'),
        );
      });

      test('a wrapper keeping the text answers with it', () {
        const padded = HWPadding(
          padding: HWEdgeInsets.only(left: 4),
          child: HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
        );
        expect(padded.kotlinBaselineText()?.ascent('data'), contains('21f'));
        const colored = HWColoredBox(
          color: HWFixedColor(0xFF00FF00),
          child: HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
        );
        expect(colored.kotlinBaselineText()?.ascent('data'), contains('21f'));
        const decorated = HWDecoratedBox(
          decoration: HWBoxDecoration(color: HWFixedColor(0xFF00FF00)),
          child: HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
        );
        expect(decorated.kotlinBaselineText()?.ascent('data'), contains('21f'));
      });

      test('a wrapper putting room above the text answers null', () {
        const padded = HWPadding(
          padding: HWEdgeInsets.all(4),
          child: HWText.fixed('a'),
        );
        expect(padded.kotlinBaselineText(), isNull);
        const bordered = HWDecoratedBox(
          decoration: HWBoxDecoration(
            border: HWBoxBorder(thickness: 1, color: HWFixedColor(0)),
          ),
          child: HWText.fixed('a'),
        );
        expect(bordered.kotlinBaselineText(), isNull);
        const filled = HWSizedBox.expand(child: HWText.fixed('a'));
        expect(filled.kotlinBaselineText(), isNull);
      });

      test('a layout of several children answers null', () {
        const column = HWColumn(
          children: [
            HWImage(HWImageData('avatar'), width: 8),
            HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
          ],
        );
        expect(column.kotlinBaselineText(), isNull);
        const row = HWRow(children: [HWText.fixed('a')]);
        expect(row.kotlinBaselineText(), isNull);
      });

      test('an adaptive answers with its Android side', () {
        const adaptive = HWAdaptive(
          ios: HWText.fixed('a', style: HWTextStyle(fontSize: 11)),
          android: HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
        );
        expect(adaptive.kotlinBaselineText()?.ascent('data'), contains('21f'));
        const textless = HWAdaptive(
          ios: HWText.fixed('a'),
          android: HWImage(HWImageData('avatar'), width: 8),
        );
        expect(textless.kotlinBaselineText(), isNull);
      });

      test('a conditional answers with both of its branches', () {
        const conditional = HWDataExists(
          data: HWString('maybe'),
          whenPresent: HWText.fixed('a', style: HWTextStyle(fontSize: 19)),
          whenAbsent: HWText.fixed(
            'b',
            style: HWTextStyle(fontFamily: 'Chewy', fontSize: 11),
          ),
        );
        final baseline = conditional.kotlinBaselineText()!;
        expect(baseline.isBitmap, isTrue);
        expect(
          baseline.ascent('data'),
          startsWith('if (data.maybe != null) HomeWidgetFonts.textAscentPx('),
        );
        expect(baseline.ascent('data'), contains('19f'));
        expect(baseline.ascent('data'), contains('11f'));
      });

      test('a conditional with a branch rendering no text answers null', () {
        const textless = HWDataExists(
          data: HWString('maybe'),
          whenPresent: HWImage(HWImageData('avatar'), width: 8),
          whenAbsent: HWText.fixed('b'),
        );
        expect(textless.kotlinBaselineText(), isNull);
      });

      test('a size-adaptive answers when every slot agrees', () {
        const adaptive = HWSizeAdaptive(
          small: HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
          large: HWText.fixed('b', style: HWTextStyle(fontSize: 21)),
        );
        expect(adaptive.kotlinBaselineText()?.ascent('data'), contains('21f'));
      });

      test('a size-adaptive rendering no text at all answers null', () {
        const adaptive = HWSizeAdaptive(
          small: HWImage(HWImageData('avatar'), width: 8),
          accessoryInline: HWText.fixed('a'),
        );
        expect(adaptive.kotlinBaselineText(), isNull);
      });

      test('a size-adaptive whose slots differ is rejected', () {
        expect(
          () => _baselineRow(_differingSlots).toKotlin(0, dataExpr: 'data'),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('HWCrossAxisAlignment.baseline'),
                contains('HWSizeAdaptive'),
              ),
            ),
          ),
        );
        const partial = HWSizeAdaptive(
          small: HWText.fixed('a'),
          large: HWImage(HWImageData('avatar'), width: 8),
        );
        expect(
          () => _baselineRow(partial).toKotlin(0, dataExpr: 'data'),
          throwsA(isA<GeneratorError>()),
        );
      });

      test('a slot no family reaches is left out of the comparison', () {
        const context = HWEmitContext(
          reachableFamilies: {
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.systemMedium,
          },
        );
        final baseline = _differingSlots.kotlinBaselineText(context)!;
        expect(baseline.conflict, isNull);
        expect(baseline.ascent('data'), contains('21f'));
        expect(
          _baselineRow(_differingSlots)
              .toKotlin(0, dataExpr: 'data', context: context),
          contains('21f'),
        );
      });

      test('without a context every slot written is compared', () {
        expect(
          _differingSlots.kotlinBaselineText()?.conflict,
          contains('HWSizeAdaptive'),
        );
        expect(
          _baselineRow(_differingSlots).kotlinImports,
          contains('import es.antonborri.home_widget.HomeWidgetFonts'),
        );
      });

      test('a bitmap slot behind a plain one still brings the row imports', () {
        const row = HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          children: [
            HWSizeAdaptive(
              small: HWText.fixed('a'),
              large: HWText.fixed(
                'b',
                style: HWTextStyle(fontFamily: 'Chewy', fontSize: 18),
              ),
            ),
            HWText.fixed('c'),
          ],
        );
        const context = HWEmitContext(
          reachableFamilies: {HWWidgetFamily.systemLarge},
        );
        expect(
          row.toKotlin(0, dataExpr: 'data', context: context),
          contains('HomeWidgetFonts.baselinePadding'),
        );
        expect(
          row.kotlinImports,
          containsAll([
            'import androidx.glance.layout.Box',
            'import androidx.glance.layout.padding',
            'import es.antonborri.home_widget.HomeWidgetFonts',
          ]),
        );
      });

      test('a widget rendering no text of its own answers null', () {
        const image = HWImage(HWImageData('avatar'), width: 8);
        expect(image.kotlinBaselineText(), isNull);
      });
    });
  });
}

/// A size-adaptive whose two slots render text of a different size.
const _differingSlots = HWSizeAdaptive(
  small: HWText.fixed('a', style: HWTextStyle(fontSize: 21)),
  large: HWText.fixed('b', style: HWTextStyle(fontSize: 11)),
);

/// A baseline row of [child] beside a bitmap text, which is what makes the row
/// place its children itself.
HWRow _baselineRow(HWWidget child) => HWRow(
      crossAxisAlignment: HWCrossAxisAlignment.baseline,
      children: [
        child,
        const HWText.fixed(
          'c',
          style: HWTextStyle(fontFamily: 'Chewy', fontSize: 18),
        ),
      ],
    );
