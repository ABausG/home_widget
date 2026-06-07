import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWColumn', () {
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
  });

  group('HWRow', () {
    test('const constructor', () {
      const row = HWRow(children: [HWText.fixed('x')]);
      expect(row, isA<HWRow>());
      expect(row, isA<HWWidget>());
      expect(row.children, hasLength(1));
    });
  });

  group('nesting', () {
    test('Column in Row', () {
      const widget = HWRow(
        children: [
          HWColumn(children: [HWText.fixed('nested')]),
        ],
      );
      expect(widget.children.first, isA<HWColumn>());
    });

    test('Row in Column', () {
      const widget = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      expect(widget.children.first, isA<HWRow>());
    });

    test('deep nesting (3+ levels)', () {
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

    test('mixed children types', () {
      const widget = HWRow(
        children: [
          HWText.fixed('a'),
          HWColumn(children: [HWText.fixed('b')]),
        ],
      );
      expect(widget.children[0], isA<HWText>());
      expect(widget.children[1], isA<HWColumn>());
    });

    test('data ref in nested tree', () {
      const widget = HWColumn(
        children: [
          HWText(HWString('key')),
        ],
      );
      expect(widget.children.first, isA<HWText>());
    });
  });

  group('Column and Row · Kotlin (Glance)', () {
    test('Column from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('Text(text = "a")'));
      expect(result, contains('Text(text = "b")'));
    });

    test('Row from HWRow', () {
      final node = HWRow(
        children: [
          HWText.fixed('x'),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "x")'));
    });

    test('nested Column/Row', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
          HWText.fixed('y'),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "x")'));
      expect(result, contains('Text(text = "y")'));
    });

    test('data in layout', () {
      final node = HWColumn(
        children: [
          HWText(HWString('count')),
        ],
      );
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, contains('Column {'));
      expect(result, contains('Text(text = data.count ?: "")'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, startsWith('Column {'));
      expect(result, contains('    Row {'));
      expect(result, contains('        Text(text = "x")'));
    });

    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        contains(
          'Column(horizontalAlignment = Alignment.CenterHorizontally) {',
        ),
      );
    });

    test('Row with .start alignment', () {
      final node = HWRow(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.start,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Row(verticalAlignment = Alignment.Top) {'));
    });

    test('no alignment emits bare layout', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, isNot(contains('horizontalAlignment')));
    });

    test(
        'Column with .center emits Spacer before and after (mainAxisAlignment)',
        () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(
        result,
        contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
      );
      expect(result, contains('Text(text = "a")'));
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(result)
            .length,
        2,
      );
    });

    test('Row with .spaceBetween emits Spacer between children', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "a")'));
      expect(
        result,
        contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
      );
      expect(result, contains('Text(text = "b")'));
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(result)
            .length,
        1,
      );
    });

    test('Column with both cross and main alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
        mainAxisAlignment: HWMainAxisAlignment.end,
      );
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(
        result,
        contains('horizontalAlignment = Alignment.CenterHorizontally'),
      );
      expect(
        result,
        contains('Spacer(modifier = GlanceModifier.defaultWeight())'),
      );
      expect(
        'Spacer(modifier = GlanceModifier.defaultWeight())'
            .allMatches(result)
            .length,
        1,
      );
    });
  });

  group('Column and Row · Swift (SwiftUI)', () {
    test('VStack from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('Text("a")'));
      expect(result, contains('Text("b")'));
    });

    test('HStack from HWRow', () {
      final node = HWRow(
        children: [
          HWText.fixed('x'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('HStack {'));
      expect(result, contains('Text("x")'));
    });

    test('nested VStack/HStack', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
          HWText.fixed('y'),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('HStack {'));
      expect(result, contains('Text("x")'));
      expect(result, contains('Text("y")'));
    });

    test('data in layout', () {
      final node = HWColumn(
        children: [
          HWText(HWString('countLabel')),
        ],
      );
      final result = node.toSwift(
        0,
        dataExpr: 'entry.widgetData',
      );
      expect(result, contains('VStack {'));
      expect(result, contains('Text(entry.widgetData.countLabel ?? "")'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, startsWith('VStack {'));
      expect(result, contains('    HStack {'));
      expect(result, contains('        Text("x")'));
    });

    test('Column with .start alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.start,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .leading) {'));
    });

    test('Row with .end alignment', () {
      final node = HWRow(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.end,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('HStack(alignment: .bottom) {'));
    });

    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .center) {'));
    });

    test('no alignment emits bare stack', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, isNot(contains('alignment:')));
    });

    test(
        'Column with .center emits Spacer before and after (mainAxisAlignment)',
        () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      expect('Spacer()'.allMatches(result).length, 2);
    });

    test('Column with .end emits Spacer before children', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.end,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Row with .spaceBetween emits Spacer between children', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, contains('HStack {'));
      expect(result, contains('Text("a")'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("b")'));
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Column with .spaceEvenly emits Spacer around all children', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
        mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect('Spacer()'.allMatches(result).length, 3);
    });

    test('Column with .start emits no spacers', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.start,
      );
      final result = node.toSwift(0, dataExpr: 'data');
      expect(result, isNot(contains('Spacer()')));
    });
  });
}
