import 'package:home_widget_cli/src/generators/swift_widget_emitter.dart';
import 'package:home_widget_cli/src/models/widget_node.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:test/test.dart';

void main() {
  group('emitSwiftWidgetBody', () {
    test('emits fixed text', () {
      final node = TextNode(content: StaticValue('Hello'));
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text("Hello")');
    });

    test('emits string data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'label', type: HWDataFieldType.string),
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(data.label ?? "")');
    });

    test('emits int data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'count', type: HWDataFieldType.int_),
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(data.count != nil ? "\\(data.count!)" : "0")');
    });

    test('emits bool data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'flag', type: HWDataFieldType.bool_),
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(data.flag != nil ? "\\(data.flag!)" : "false")');
    });

    test('emits double data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'ratio', type: HWDataFieldType.double_),
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(data.ratio != nil ? "\\(data.ratio!)" : "0.0")');
    });

    test('escapes strings', () {
      final node = TextNode(content: StaticValue('He said "Hi"'));
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text("He said \\"Hi\\"")');
    });

    test('respects indent', () {
      final node = TextNode(content: StaticValue('Hello'));
      final result = emitSwiftWidgetBody(node, dataExpr: 'data', indent: 1);
      expect(result, '    Text("Hello")');
    });

    test('VStack from ColumnNode', () {
      final node = ColumnNode(
        children: [
          TextNode(content: StaticValue('a')),
          TextNode(content: StaticValue('b')),
        ],
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('Text("a")'));
      expect(result, contains('Text("b")'));
    });

    test('HStack from RowNode', () {
      final node = RowNode(
        children: [
          TextNode(content: StaticValue('x')),
        ],
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('HStack {'));
      expect(result, contains('Text("x")'));
    });

    test('nested VStack/HStack', () {
      final node = ColumnNode(
        children: [
          RowNode(children: [TextNode(content: StaticValue('x'))]),
          TextNode(content: StaticValue('y')),
        ],
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('HStack {'));
      expect(result, contains('Text("x")'));
      expect(result, contains('Text("y")'));
    });

    test('data in layout', () {
      final node = ColumnNode(
        children: [
          TextNode(
            content:
                DataRefValue(key: 'countLabel', type: HWDataFieldType.string),
          ),
        ],
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'entry.widgetData');
      expect(result, contains('VStack {'));
      expect(result, contains('Text(entry.widgetData.countLabel ?? "")'));
    });

    test('empty Column', () {
      final node = ColumnNode(children: []);
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = ColumnNode(
        children: [
          RowNode(children: [TextNode(content: StaticValue('x'))]),
        ],
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data', indent: 0);
      // Root VStack at 0 indent
      expect(result, startsWith('VStack {'));
      // HStack at 4 spaces
      expect(result, contains('    HStack {'));
      // Text at 8 spaces
      expect(result, contains('        Text("x")'));
    });

    test('Column with .start alignment', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.start,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .leading) {'));
    });

    test('Row with .end alignment', () {
      final node = RowNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.end,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('HStack(alignment: .bottom) {'));
    });

    test('Column with .center alignment', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.center,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack(alignment: .center) {'));
    });

    test('no alignment emits bare stack', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, isNot(contains('alignment:')));
    });
  });

  group('mainAxisAlignment emitter', () {
    test('Column with .center emits Spacer before and after', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        mainAxisAlignment: MainAxisAlignment.center,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('VStack {'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      // Should have 2 spacers
      expect('Spacer()'.allMatches(result).length, 2);
    });

    test('Column with .end emits Spacer before children', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        mainAxisAlignment: MainAxisAlignment.end,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("a")'));
      // Only 1 spacer (before)
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Row with .spaceBetween emits Spacer between children', () {
      final node = RowNode(
        children: [
          TextNode(content: StaticValue('a')),
          TextNode(content: StaticValue('b')),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, contains('HStack {'));
      expect(result, contains('Text("a")'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text("b")'));
      // 1 spacer between 2 children
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Column with .spaceEvenly emits Spacer around all children', () {
      final node = ColumnNode(
        children: [
          TextNode(content: StaticValue('a')),
          TextNode(content: StaticValue('b')),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      // Spacer before first, between, and after last = 3 spacers
      expect('Spacer()'.allMatches(result).length, 3);
    });

    test('Column with .start emits no spacers', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        mainAxisAlignment: MainAxisAlignment.start,
      );
      final result = emitSwiftWidgetBody(node, dataExpr: 'data');
      expect(result, isNot(contains('Spacer()')));
    });
  });
}
