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
      test('HStack with children defaults to center', () {
        final node = HWRow(children: [HWText.fixed('x')]);
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('Text("x")'));
      });

      test('crossAxis .start → top', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .top, spacing: 0) {'));
      });

      test('crossAxis .center → center', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center, spacing: 0) {'));
      });

      test('crossAxis .end → bottom', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .bottom, spacing: 0) {'));
      });

      test('crossAxis .baseline → firstTextBaseline', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(
          r,
          contains('HStack(alignment: .firstTextBaseline, spacing: 0) {'),
        );
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWRow(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('HStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('Text("a")'));
        expect(r, contains('Spacer(minLength: 0)'));
        expect(r, contains('Text("b")'));
        expect('Spacer(minLength: 0)'.allMatches(r).length, 1);
      });

      test('mainAxis .center wraps with Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.center,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer(minLength: 0)'.allMatches(r).length, 2);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });

      test('mainAxis .end leads with Spacer', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.end,
          children: [HWText.fixed('a')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer(minLength: 0)'.allMatches(r).length, 1);
        expect(r, contains('Text("a")'));
      });

      test('mainAxis .spaceEvenly has Spacer between and around', () {
        final node = HWRow(
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer(minLength: 0)'.allMatches(r).length, 3);
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
            HWFill(child: HWText.fixed('b')),
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

      test('a size-adaptive child wraps each slot that is text', () {
        const textSlot = HWSizeAdaptive(
          small: HWText.fixed('a'),
          large: HWText.fixed('b'),
        );
        final imageSlot = HWSizeAdaptive(
          small: HWImage(HWImageData('avatar'), width: 8),
          large: HWImage(HWImageData('avatar'), width: 8),
        );
        final node = HWRow(
          children: [textSlot, imageSlot],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect('Box {'.allMatches(r).length, 2);
        expect(
          r,
          contains(
            '            Box {\n'
            '                Text(text = "b", ',
          ),
        );
      });

      test('a conditional child wraps only the branch that is text', () {
        const node = HWRow(
          crossAxisAlignment: HWCrossAxisAlignment.start,
          children: [
            HWDataExists(
              data: HWString('title'),
              whenPresent: HWRow(
                mainAxisAlignment: HWMainAxisAlignment.center,
                children: [HWText(HWString('title'))],
              ),
              whenAbsent: HWText.fixed('none'),
            ),
          ],
        );
        expect(node.toKotlin(0, dataExpr: 'data'), '''
Row(verticalAlignment = Alignment.Top) {
    if (data.title != null) {
        Row(modifier = GlanceModifier.defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            Text(text = data.title ?: "", style = TextStyle(color = GlanceTheme.colors.onSurface))
            Spacer(modifier = GlanceModifier.defaultWeight())
        }
    } else {
        Box {
            Text(text = "none", style = TextStyle(color = GlanceTheme.colors.onSurface))
        }
    }
}''');
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );
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

      test('a wrapped child is laid out by the Box, which takes its weight',
          () {
        const node = HWRow(
          children: [
            HWText.fixed('a'),
            HWColoredBox(
              color: HWColor.fixed(0xFF00FF00),
              child: HWRow(
                children: [HWText.fixed('b')],
                mainAxisAlignment: HWMainAxisAlignment.center,
              ),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.start,
          spacing: 4,
        );
        const slots = HWRow(
          children: [
            HWText.fixed('a'),
            HWSizeAdaptive(
              small: HWText.fixed('a'),
              large: HWRow(
                children: [HWText.fixed('b')],
                mainAxisAlignment: HWMainAxisAlignment.center,
              ),
            ),
          ],
          crossAxisAlignment: HWCrossAxisAlignment.start,
          spacing: 4,
        );
        final r = slots.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Row(modifier = GlanceModifier.padding(start = 4.0.dp)'
            '.defaultWeight(), ',
          ),
        );
        expect(
          r,
          contains('Box(modifier = GlanceModifier.padding(start = 4.0.dp)) {'),
        );
        expect(
          slots.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxWidth')),
        );

        final wrapped = node.toKotlin(0, dataExpr: 'data');
        expect(
          wrapped,
          contains(
            'Box(modifier = GlanceModifier.defaultWeight()'
            '.padding(start = 4.0.dp)) {',
          ),
        );
        expect(wrapped, contains('.fillMaxWidth(), verticalAlignment'));
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
          const HWFill(child: row).toKotlin(0, dataExpr: 'data'),
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

      group('with a text boxed for its gap', () {
        const large = 'HomeWidgetFonts.textAscentPx(context, null, 32f, '
            'weight = 400, italic = false)';
        const small = 'HomeWidgetFonts.textAscentPx(context, null, 12f, '
            'weight = 400, italic = false)';
        const red = HWFixedColor(0xFFFF0000);
        const degrees = HWText.fixed('42', style: HWTextStyle(fontSize: 32));
        const unit = HWText.fixed('°C', style: HWTextStyle(fontSize: 12));

        test('places every text, as it has no baseline in the Box', () {
          const node = HWRow(
            spacing: 8,
            crossAxisAlignment: HWCrossAxisAlignment.baseline,
            children: [degrees, HWColoredBox(color: red, child: unit)],
          );
          expect(node.toKotlin(0, dataExpr: 'data'), '''
Row(verticalAlignment = Alignment.Top) {
    Box(modifier = GlanceModifier.padding(top = HomeWidgetFonts.baselinePadding(context, listOf($large, $small), 0))) {
        Text(text = "42", style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 32.sp))
    }
    Box(modifier = GlanceModifier.padding(top = HomeWidgetFonts.baselinePadding(context, listOf($large, $small), 1)).padding(start = 8.0.dp)) {
        Text(modifier = GlanceModifier.background(ColorProvider(day = Color(0xFFFF0000), night = Color(0xFFFF0000))), text = "°C", style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 12.sp))
    }
}''');
          expect(
            node.kotlinImports,
            containsAll([
              'import androidx.glance.layout.Box',
              'import androidx.glance.layout.padding',
              'import es.antonborri.home_widget.HomeWidgetFonts',
            ]),
          );
        });

        test('places every text when one branch is boxed', () {
          const node = HWRow(
            spacing: 8,
            crossAxisAlignment: HWCrossAxisAlignment.baseline,
            children: [
              degrees,
              HWBoolConditional(
                data: HWBool('fahrenheit', defaultValue: false),
                whenTrue: HWColoredBox(color: red, child: unit),
                whenFalse: unit,
              ),
            ],
          );
          final r = node.toKotlin(0, dataExpr: 'data');
          expect('HomeWidgetFonts.baselinePadding('.allMatches(r).length, 3);
          expect(
            r,
            contains(
              '    if (data.fahrenheit == true) {\n'
              '        Box(modifier = GlanceModifier.padding(top = '
              'HomeWidgetFonts.baselinePadding(',
            ),
          );
        });

        test('leaves texts taking the gap themselves to the layout', () {
          const node = HWRow(
            spacing: 8,
            crossAxisAlignment: HWCrossAxisAlignment.baseline,
            children: [
              degrees,
              unit,
              HWColoredBox(
                color: red,
                child: HWIcon.glyph(0xe800, font: HWIconFont(family: 'Icons')),
              ),
            ],
          );
          final r = node.toKotlin(0, dataExpr: 'data');
          expect(r, isNot(contains('baselinePadding')));
          expect(
            r,
            contains(
              'Text(modifier = GlanceModifier.padding(start = 8.0.dp), '
              'text = "°C", ',
            ),
          );
          expect(
            r,
            contains(
              'Box(modifier = GlanceModifier.padding(start = 8.0.dp)) {\n'
              '        Image(',
            ),
          );
        });

        test('leaves a row without spacing to the layout', () {
          const node = HWRow(
            crossAxisAlignment: HWCrossAxisAlignment.baseline,
            children: [degrees, HWColoredBox(color: red, child: unit)],
          );
          expect(
            node.toKotlin(0, dataExpr: 'data'),
            isNot(contains('Box')),
          );
        });
      });
    });

    group('Android baseline alignment of list items', () {
      const bitmapLabel = HWText(
        HWItemData(HWString('label')),
        style: HWTextStyle(fontFamily: 'Chewy', fontSize: 28),
      );
      const plainLabel = HWText(
        HWItemData(HWString('label')),
        style: HWTextStyle(fontSize: 14),
      );
      const score = HWBoolConditional(
        data: HWItemData(HWBool('big', defaultValue: false)),
        whenTrue: bitmapLabel,
        whenFalse: plainLabel,
      );
      const bitmapAscent = 'HomeWidgetFonts.textAscentPx(context, '
          'HomeWidgetFonts.typeface(context, "Chewy", 400, false), 28f)';
      const plainAscent = 'HomeWidgetFonts.textAscentPx(context, null, 14f, '
          'weight = 400, italic = false)';

      List<String> lines(String code) =>
          code.split('\n').map((line) => line.trim()).toList();

      test('pads items whose ascent reads their item to the deepest one', () {
        const row = HWRow.builder(
          'scores',
          maxItems: 3,
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: score,
        );

        const placed = 'Box(modifier = GlanceModifier.padding(top = '
            'HomeWidgetFonts.baselinePadding(context, hwAscents, hwIndex))) {';
        final kotlin = lines(row.toKotlin(0, dataExpr: 'data'));
        expect(kotlin.take(6), [
          'Row(verticalAlignment = Alignment.Top) {',
          'val hwItems = data.scores.orEmpty().take(3)',
          'val hwAscents = hwItems.map { hwItem -> if (hwItem.big == true) '
              '$bitmapAscent else $plainAscent }',
          'hwItems.forEachIndexed { hwIndex, hwItem ->',
          'if (hwItem.big == true) {',
          placed,
        ]);
        expect(kotlin.where((line) => line == placed), hasLength(2));
        expect(
          row.kotlinImports,
          containsAll([
            'import androidx.glance.layout.Box',
            'import androidx.glance.layout.padding',
            'import es.antonborri.home_widget.HomeWidgetFonts',
          ]),
        );
        expect(
          row.toSwift(0, dataExpr: 'data'),
          startsWith(
            'HStack(alignment: .firstTextBaseline, spacing: 0) {\n'
            r'    ForEach(Array((data.scores ?? []).prefix(3).enumerated()), '
            r'id: \.offset) { hwIndex, hwItem in',
          ),
        );
      });

      test('measures every item without maxItems', () {
        const row = HWRow.builder(
          'scores',
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: score,
        );

        expect(
          row.toKotlin(0, dataExpr: 'data'),
          contains(
            'val hwItems = data.scores.orEmpty()\n'
            '    val hwAscents = hwItems.map { hwItem -> ',
          ),
        );
      });

      test('leaves items alone whose ascent reads nothing of their item', () {
        const row = HWRow.builder(
          'scores',
          maxItems: 3,
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: bitmapLabel,
        );
        final kotlin = row.toKotlin(0, dataExpr: 'data');

        expect(kotlin, isNot(contains('hwAscents')));
        expect(kotlin, isNot(contains('Box')));
        expect(
          row.kotlinImports,
          isNot(contains('import androidx.glance.layout.padding')),
        );
      });

      test('leaves items of plain text to the layout', () {
        const row = HWRow.builder(
          'scores',
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: HWBoolConditional(
            data: HWItemData(HWBool('big', defaultValue: false)),
            whenTrue: HWText(HWItemData(HWString('label'))),
            whenFalse: plainLabel,
          ),
        );

        expect(row.toKotlin(0, dataExpr: 'data'), isNot(contains('Box')));
      });

      test('leaves an item rendering no text at the top', () {
        const row = HWRow.builder(
          'scores',
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: HWImage(HWItemData(HWImageData('avatar'))),
        );

        expect(
          row.toKotlin(0, dataExpr: 'data'),
          isNot(contains('baselinePadding')),
        );
      });

      test('pads items boxed for their gap whose ascent reads their item', () {
        const row = HWRow.builder(
          'scores',
          maxItems: 3,
          spacing: 6,
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: HWColoredBox(
            color: HWFixedColor(0xFFFF0000),
            child: HWBoolConditional(
              data: HWItemData(HWBool('big', defaultValue: false)),
              whenTrue: HWText(
                HWItemData(HWString('label')),
                style: HWTextStyle(fontSize: 28),
              ),
              whenFalse: plainLabel,
            ),
          ),
        );
        const placed = 'Box(modifier = GlanceModifier.padding(top = '
            'HomeWidgetFonts.baselinePadding(context, hwAscents, hwIndex))'
            '.padding(start = if (hwIndex > 0) 6.0.dp else 0.dp)) {';

        final kotlin = lines(row.toKotlin(0, dataExpr: 'data'));
        expect(kotlin.take(6), [
          'Row(verticalAlignment = Alignment.Top) {',
          'val hwItems = data.scores.orEmpty().take(3)',
          'val hwAscents = hwItems.map { hwItem -> if (hwItem.big == true) '
              'HomeWidgetFonts.textAscentPx(context, null, 28f, weight = 400, '
              'italic = false) else $plainAscent }',
          'hwItems.forEachIndexed { hwIndex, hwItem ->',
          'if (hwItem.big == true) {',
          placed,
        ]);
        expect(kotlin.where((line) => line == placed), hasLength(2));
        expect(
          row.kotlinImports,
          contains('import es.antonborri.home_widget.HomeWidgetFonts'),
        );
      });

      test('leaves boxed items of one ascent at the top of their Box', () {
        const row = HWRow.builder(
          'scores',
          maxItems: 3,
          spacing: 6,
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: HWColoredBox(
            color: HWFixedColor(0xFFFF0000),
            child: plainLabel,
          ),
        );
        final kotlin = row.toKotlin(0, dataExpr: 'data');

        expect(kotlin, isNot(contains('hwAscents')));
        expect(
          kotlin,
          contains(
            'Box(modifier = GlanceModifier.padding(start = if (hwIndex > 0) '
            '6.0.dp else 0.dp)) {',
          ),
        );
      });

      test('rejects an item whose slots render text differently', () {
        const row = HWRow.builder(
          'scores',
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
          item: HWSizeAdaptive(small: score, large: plainLabel),
        );

        expect(
          () => row.toKotlin(0, dataExpr: 'data'),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('HWSizeAdaptive whose slots render text differently'),
            ),
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
        const filled = HWFill(child: HWText.fixed('a'));
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
