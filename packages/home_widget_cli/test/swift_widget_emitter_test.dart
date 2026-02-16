import 'package:home_widget_cli/src/generators/swift_widget_emitter.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('emitSwiftWidgetBody', () {
    test('emits fixed text', () {
      final node = HWText.fixed('Hello');
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, 'Text("Hello")');
    });

    test('emits string data ref', () {
      final node = HWText.data(HWDataRef('label'));
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'label', type: HWDataFieldType.string),
        ],
      );
      expect(result, 'Text(data.label ?? "")');
    });

    test('emits int data ref', () {
      final node = HWText.data(HWDataRef('count'));
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'count', type: HWDataFieldType.int_),
        ],
      );
      expect(result, 'Text(data.count != nil ? "\\(data.count!)" : "0")');
    });

    test('emits bool data ref', () {
      final node = HWText.data(HWDataRef('flag'));
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'flag', type: HWDataFieldType.bool_),
        ],
      );
      expect(result, 'Text(data.flag != nil ? "\\(data.flag!)" : "false")');
    });

    test('emits double data ref', () {
      final node = HWText.data(HWDataRef('ratio'));
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'ratio', type: HWDataFieldType.double_),
        ],
      );
      expect(result, 'Text(data.ratio != nil ? "\\(data.ratio!)" : "0.0")');
    });

    test('escapes strings', () {
      final node = HWText.fixed('He said "Hi"');
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, 'Text("He said \\"Hi\\"")');
    });

    test('respects indent', () {
      final node = HWText.fixed('Hello');
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [],
        indent: 1,
      );
      expect(result, '    Text("Hello")');
    });

    test('VStack from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('VStack {'));
      expect(result, contains('HStack {'));
      expect(result, contains('Text("x")'));
      expect(result, contains('Text("y")'));
    });

    test('data in layout', () {
      final node = HWColumn(
        children: [
          HWText.data(HWDataRef('countLabel')),
        ],
      );
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'entry.widgetData',
        dataFields: [
          DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
        ],
      );
      expect(result, contains('VStack {'));
      expect(result, contains('Text(entry.widgetData.countLabel ?? "")'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('VStack {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = emitSwiftWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [],
        indent: 0,
      );
      // Root VStack at 0 indent
      expect(result, startsWith('VStack {'));
      // HStack at 4 spaces
      expect(result, contains('    HStack {'));
      // Text at 8 spaces
      expect(result, contains('        Text("x")'));
    });

    test('Column with .start alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.start,
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('VStack(alignment: .leading) {'));
    });

    test('Row with .end alignment', () {
      final node = HWRow(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.end,
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('HStack(alignment: .bottom) {'));
    });

    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('VStack(alignment: .center) {'));
    });

    test('no alignment emits bare stack', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('VStack {'));
      expect(result, isNot(contains('alignment:')));
    });
  });

  group('mainAxisAlignment emitter', () {
    test('Column with .center emits Spacer before and after', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('VStack {'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      // Should have 2 spacers
      expect('Spacer()'.allMatches(result).length, 2);
    });

    test('Column with .end emits Spacer before children', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.end,
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      // Only 1 spacer (before)
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
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('HStack {'));
      expect(result, contains('Text("a")'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("b")'));
      // 1 spacer between 2 children
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
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      // Spacer before first, between, and after last = 3 spacers
      expect('Spacer()'.allMatches(result).length, 3);
    });

    test('Column with .start emits no spacers', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.start,
      );
      final result =
          emitSwiftWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, isNot(contains('Spacer()')));
    });
  });
}
