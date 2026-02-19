import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidget.toKotlin', () {
    test('emits fixed text', () {
      final node = HWText.fixed('Hello');
      final result = node.toKotlin(0, dataExpr: 'data');
      expect(result, 'Text(text = "Hello")');
    });

    test('emits string data ref', () {
      final node = HWText(HWString('label'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = data.label ?: "")');
    });

    test('emits int data ref', () {
      final node = HWText(HWInt('count'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = (data.count?.toString() ?: "0"))');
    });

    test('emits bool data ref', () {
      final node = HWText(HWBool('flag'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = (data.flag?.toString() ?: "false"))');
    });

    test('emits double data ref', () {
      final node = HWText(HWDouble('ratio'));
      final result = node.toKotlin(
        0,
        dataExpr: 'data',
      );
      expect(result, 'Text(text = (data.ratio?.toString() ?: "0.0"))');
    });

    test('escapes strings', () {
      final node = HWText.fixed('Price: \$5');
      final result = node.toKotlin(0, dataExpr: 'data');
      // Note: In toKotlin, $ is escaped to \$, so output is Price: \$5
      // Dart string literal needs \\$ for \$ in regex or string.
      // Emitter logic: s.replaceAll('$', '\\$') -> produces `\$`
      // Kotlin string: "Price: \$5"
      // Test expectation string: 'Text(text = "Price: \\\$5")'
      expect(result, 'Text(text = "Price: \\\$5")');
    });

    test('respects indent', () {
      final node = HWText.fixed('Hello');
      final result = node.toKotlin(1, dataExpr: 'data');
      expect(result, '    Text(text = "Hello")');
    });

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
      expect(result, contains('Spacer()'));
      expect(result, contains('Text(text = "a")'));
      expect('Spacer()'.allMatches(result).length, 2);
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
      expect(result, contains('Spacer()'));
      expect(result, contains('Text(text = "b")'));
      expect('Spacer()'.allMatches(result).length, 1);
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
      expect(result, contains('Spacer()'));
      // end = 1 spacer before children
      expect('Spacer()'.allMatches(result).length, 1);
    });
  });
}
