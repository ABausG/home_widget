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

      test('crossAxis .baseline → Top with the baselines kept', () {
        final node = HWRow(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Row(verticalAlignment = Alignment.Top) {'));
        expect(r, isNot(contains('Box {')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.Box')),
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
    });
  });
}
