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
    });

    group('iOS (SwiftUI)', () {
      test('VStack with children', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack {'));
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
        expect(r, contains('VStack {'));
        expect(r, contains('HStack {'));
        expect(r, contains('Text("x")'));
        expect(r, contains('Text("y")'));
      });

      test('data-bound text in column', () {
        final node = HWColumn(children: [HWText(HWString('countLabel'))]);
        final r = node.toSwift(0, dataExpr: 'entry.widgetData');
        expect(r, contains('VStack {'));
        expect(r, contains('Text(entry.widgetData.countLabel ?? "")'));
      });

      test('empty column', () {
        final r = HWColumn(children: []).toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack {'));
        expect(r, contains('}'));
      });

      test('indentation with nested HStack', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
          ],
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, startsWith('VStack {'));
        expect(r, contains('    HStack {'));
        expect(r, contains('        Text("x")'));
      });

      test('crossAxis .start → leading', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.start,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .leading) {'));
      });

      test('crossAxis .center', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .center) {'));
      });

      test('bare VStack when no alignment', () {
        final node = HWColumn(children: [HWText.fixed('a')]);
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack {'));
        expect(r, isNot(contains('alignment:')));
      });

      test('mainAxis .center uses Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack {'));
        expect(r, contains('Spacer()'));
        expect(r, contains('Text("a")'));
        expect('Spacer()'.allMatches(r).length, 2);
      });

      test('mainAxis .end uses leading Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('Spacer()'));
        expect(r, contains('Text("a")'));
        expect('Spacer()'.allMatches(r).length, 1);
      });

      test('mainAxis .spaceEvenly', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 3);
      });

      test('mainAxis .spaceBetween and Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a'), HWText.fixed('b')],
          mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect('Spacer()'.allMatches(r).length, 1);
        expect(r, contains('Text("a")'));
        expect(r, contains('Text("b")'));
      });

      test('crossAxis .end → trailing', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          crossAxisAlignment: HWCrossAxisAlignment.end,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, contains('VStack(alignment: .trailing) {'));
      });

      test('mainAxis .start has no Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.start,
        );
        final r = node.toSwift(0, dataExpr: 'data');
        expect(r, isNot(contains('Spacer()')));
      });
    });

    group('Android (Glance)', () {
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
        expect(r, contains('Column {'));
        expect(r, contains('Text(text = "a")'));
        expect(r, contains('Text(text = "b")'));
      });

      test('nested Column and Row', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
            HWText.fixed('y'),
          ],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Column {'));
        expect(r, contains('Row {'));
        expect(r, contains('Text(text = "x")'));
        expect(r, contains('Text(text = "y")'));
      });

      test('data-bound child', () {
        final node = HWColumn(children: [HWText(HWString('count'))]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Column {'));
        expect(r, contains('Text(text = data.count ?: "")'));
      });

      test('empty column', () {
        final r = HWColumn(children: []).toKotlin(0, dataExpr: 'data');
        expect(r, contains('Column {'));
        expect(r, contains('}'));
      });

      test('indentation', () {
        final node = HWColumn(
          children: [
            HWRow(children: [HWText.fixed('x')]),
          ],
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, startsWith('Column {'));
        expect(r, contains('    Row {'));
        expect(r, contains('        Text(text = "x")'));
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

      test('no cross-axis alignment → bare Column', () {
        final node = HWColumn(children: [HWText.fixed('a')]);
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Column {'));
        expect(r, isNot(contains('horizontalAlignment')));
      });

      test('mainAxis .center and Spacer', () {
        final node = HWColumn(
          children: [HWText.fixed('a')],
          mainAxisAlignment: HWMainAxisAlignment.center,
        );
        final r = node.toKotlin(0, dataExpr: 'data');
        expect(r, contains('Column {'));
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
        expect(r, contains('Text(text = "a")'));
        expect(r, contains('Text(text = "b")'));
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
        expect(r, contains('Text(text = "a")'));
        expect(r, contains('Text(text = "b")'));
      });
    });
  });
}
