import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWColumn', () {
    group('model', () {
      test('const constructor', () {
        const col = HWColumn(children: [HWText.fixed('a'), HWText.fixed('b')]);
        expect(col, isA<HWColumn>());
        expect(col, isA<HWWidget>());
        expect(col.children, hasLength(2));
      });

      test('empty children', () {
        const col = HWColumn(children: []);
        expect(col.children, isEmpty);
      });

      test('Row in Column', () {
        const widget = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
          ],
        );
        expect(widget.children.first, isA<HWRow>());
      });

      test('deep nesting (column is outer)', () {
        const widget = HWColumn(
          children: [
            HWRow(
              children: [
                HWColumn(children: [HWText.fixed('deep')]),
              ],
            ),
          ],
        );
        final row = widget.children.first as HWRow;
        final innerCol = row.children.first as HWColumn;
        expect(innerCol.children.first, isA<HWText>());
      });

      test('data ref in column tree', () {
        const widget = HWColumn(
          children: [
            HWText(HWString('key')),
          ],
        );
        expect(widget.children.first, isA<HWText>());
      });

      test('kotlinImports add Alignment and Spacer when set', () {
        final w = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Alignment'),
        );
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Spacer'),
        );
      });

      test('kotlinImports carry Alignment without a cross-axis alignment', () {
        final w = HWColumn(children: [HWText.fixed('a')]);
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Alignment'),
        );
      });
    });

    group('builder', () {
      const events = HWColumn.builder(
        'events',
        maxItems: 3,
        crossAxisAlignment: HWCrossAxisAlignment.start,
        item: HWText(HWItemData(HWString('title'))),
      );

      test('const constructor', () {
        const col = HWColumn.builder(
          'events',
          maxItems: 3,
          spacing: 4,
          item: HWText.fixed('event'),
          whenEmpty: HWText.fixed('none'),
        );
        expect(col.list, 'events');
        expect(col.maxItems, 3);
        expect(col.spacing, 4);
        expect(col.item, isA<HWText>());
        expect(col.whenEmpty, isA<HWText>());
        expect(col.children, isEmpty);
        expect(col.crossAxisAlignment, isNull);
        expect(col.mainAxisAlignment, isNull);
      });

      test('loops over the items in a VStack', () {
        expect(events.toSwift(0, dataExpr: 'entry.data'), r'''
VStack(alignment: .leading, spacing: 0) {
    ForEach(Array((entry.data.events ?? []).prefix(3).enumerated()), id: \.offset) { hwIndex, hwItem in
        Text(hwItem.title ?? "")
    }
}''');
      });

      test('loops over the items in a Glance Column', () {
        expect(events.toKotlin(0, dataExpr: 'widgetData'), '''
Column(horizontalAlignment = Alignment.Start) {
    val hwItems = widgetData.events.orEmpty().take(3)
    hwItems.forEachIndexed { _, hwItem ->
        Text(text = hwItem.title ?: "", style = TextStyle(color = GlanceTheme.colors.onSurface))
    }
}''');
        expect(
          events.kotlinImports,
          containsAll([
            'import androidx.glance.layout.Column',
            'import androidx.glance.text.Text',
          ]),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('swiftFrameAlignment keeps the cross axis, never the main one', () {
        const children = [HWText.fixed('a')];
        expect(
          const HWColumn(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.start,
            mainAxisAlignment: HWMainAxisAlignment.end,
          ).swiftFrameAlignment,
          '.topLeading',
        );
        expect(
          const HWColumn(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.center,
          ).swiftFrameAlignment,
          '.top',
        );
        expect(
          const HWColumn(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.baseline,
          ).swiftFrameAlignment,
          '.top',
        );
        expect(
          const HWColumn(
            children: children,
            crossAxisAlignment: HWCrossAxisAlignment.end,
          ).swiftFrameAlignment,
          '.topTrailing',
        );
        expect(const HWColumn(children: children).swiftFrameAlignment, '.top');
      });

      test('VStack with children', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });

      test('nested VStack and HStack', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
            HWText.fixed('y'),
          ],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('HStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('Text("x")'));
        expect(r, contains('Text("y")'));
      });

      test('data-bound text in column', () {
        final node = HWColumn(children: [HWText(HWString('countLabel'))]);
        final r = node.toSwift(0, dataExpr: 'entry.widgetData');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('Text(entry.widgetData.countLabel ?? "")'));
      });

      test('empty column', () {
        final r = HWColumn(children: []).toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('}'));
      });

      test('indentation with nested HStack', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
          ],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, startsWith('VStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('    HStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('        Text("x")'));
      });

      test('crossAxis .start → leading', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .leading, spacing: 0) {'));
      });

      test('crossAxis .center', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
      });

      test('no alignment defaults to center', () {
        final node = HWColumn(children: [HWText.fixed('a')]);
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
      });

      test('crossAxis .baseline falls back to center', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
      });

      test('mainAxis .center uses Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center, spacing: 0) {'));
        expect(r, contains('Spacer(minLength: 0)'));
        expect(r, contains('Text("a")'));
        expect('Spacer(minLength: 0)'.allMatches(r).length, 2);
      });

      test('mainAxis .end uses leading Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('Spacer(minLength: 0)'));
        expect(r, contains('Text("a")'));
        expect('Spacer(minLength: 0)'.allMatches(r).length, 1);
      });

      test('mainAxis .spaceEvenly', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer(minLength: 0)'.allMatches(r).length, 3);
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer(minLength: 0)'.allMatches(r).length, 1);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });

      test('crossAxis .end → trailing', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .trailing, spacing: 0) {'));
      });

      test('mainAxis .start has no Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.start,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, isNot(contains('Spacer(')));
      });
    });

    group('Android (Glance)', () {
      const kotlinColumn =
          'Column(horizontalAlignment = Alignment.CenterHorizontally) {';
      const kotlinRow = 'Row(verticalAlignment = Alignment.CenterVertically) {';

      test('kotlinImports include Column', () {
        final w = HWColumn(children: [HWText.fixed('a')]);
        expect(
          w.kotlinImports,
          contains('import androidx.glance.layout.Column'),
        );
      });

      test('Column with children', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains(kotlinColumn));
        expect(r, contains('Text(text = "a",'));
        expect(r, contains('Text(text = "b",'));
      });

      test('nested Column and Row', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
            HWText.fixed('y'),
          ],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains(kotlinColumn));
        expect(r, contains(kotlinRow));
        expect(r, contains('Text(text = "x",'));
        expect(r, contains('Text(text = "y",'));
      });

      test('data-bound child', () {
        final node = HWColumn(children: [HWText(HWString('count'))]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains(kotlinColumn));
        expect(r, contains('Text(text = data.count ?: "",'));
      });

      test('empty column', () {
        final r = HWColumn(children: []).toKotlin(0, dataExpr: 'data');
        expect(r, contains(kotlinColumn));
        expect(r, contains('}'));
      });

      test('indentation', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
          ],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, startsWith(kotlinColumn));
        expect(r, contains('    $kotlinRow'));
        expect(r, contains('        Text(text = "x",'));
      });

      test('crossAxis .center', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Column(horizontalAlignment = Alignment.CenterHorizontally) {',
          ),
        );
      });

      test('no cross-axis alignment → CenterHorizontally', () {
        final node = HWColumn(children: [HWText.fixed('a')]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains(kotlinColumn));
      });

      test('crossAxis .baseline falls back to CenterHorizontally', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.baseline,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains(kotlinColumn));
      });

      test('mainAxis .center and Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Column(modifier = GlanceModifier.fillMaxHeight(), '
            'horizontalAlignment = Alignment.CenterHorizontally) {',
          ),
        );
        expect(
          r,
          contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
        );
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          2,
        );
      });

      test('cross and main alignment together', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
          mainAxisAlignment: HWMainAxisAlignment.end,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('horizontalAlignment = Alignment.CenterHorizontally'),
        );
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

      test('crossAxis .start → Start', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Column(horizontalAlignment = Alignment.Start) {'),
        );
      });

      test('crossAxis .end → End', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Column(horizontalAlignment = Alignment.End) {'),
        );
      });

      test('mainAxis .spaceBetween with weighted Spacers in Kotlin', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          'Spacer(modifier = GlanceModifier.defaultWeight())'
              .allMatches(r)
              .length,
          1,
        );
        expect(r, contains('Text(text = "a",'));
        expect(r, contains('Text(text = "b",'));
      });

      test('mainAxis .spaceEvenly with weighted Spacers in Kotlin', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
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
        test('mainAxis .${alignment.name} fills the height', () {
          final node = HWColumn(
            children: [HWText.fixed('a'), HWText.fixed('b')],
            mainAxisAlignment: alignment,
          );
          expect(
            node.toKotlin(0, dataExpr: 'data'),
            contains('Column(modifier = GlanceModifier.fillMaxHeight(), '),
          );
          expect(
            node.kotlinImports,
            contains('import androidx.glance.layout.fillMaxHeight'),
          );
        });
      }

      test('mainAxis .start does not fill the height', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.start,
        );
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('fillMax')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('no mainAxis alignment does not fill the height', () {
        final node = HWColumn(children: [HWText.fixed('a')]);
        expect(node.toKotlin(0, dataExpr: 'data'), isNot(contains('fillMax')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('a column in a column takes a weight rather than the height', () {
        const inner = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWColumn(children: [inner, HWText.fixed('b')]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains('Column(modifier = GlanceModifier.defaultWeight(), '),
        );
        expect(r, isNot(contains('fillMaxHeight')));
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('a column in a row still fills the height', () {
        const inner = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWRow(children: [inner]);
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains('Column(modifier = GlanceModifier.fillMaxHeight(), '),
        );
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.fillMaxHeight'),
        );
      });

      test('a wrapper keeping the column passes the axis through', () {
        const inner = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWColumn(
          children: [
            HWPadding(padding: HWEdgeInsets.all(4), child: inner),
            HWText.fixed('b'),
          ],
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains('.defaultWeight(),'),
        );
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('an adaptive passes the axis on to its Android side', () {
        const inner = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWColumn(
          children: [
            HWAdaptive(ios: HWText.fixed('a'), android: inner),
            HWText.fixed('b'),
          ],
        );
        expect(
          node.toKotlin(0, dataExpr: 'data'),
          contains('Column(modifier = GlanceModifier.defaultWeight(), '),
        );
        expect(
          node.kotlinImports,
          isNot(contains('import androidx.glance.layout.fillMaxHeight')),
        );
      });

      test('a sized box in between gives the column its height back', () {
        const inner = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        const node = HWColumn(
          children: [HWSizedBox.expand(child: inner), HWText.fixed('b')],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(
          r,
          contains(
            'Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight(), ',
          ),
        );
        expect(r, isNot(contains('fillMaxHeight()')));
        expect(
          node.kotlinImports,
          contains('import androidx.glance.layout.fillMaxHeight'),
        );
      });
    });
  });
}
