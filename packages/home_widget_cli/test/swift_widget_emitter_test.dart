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
  });
}
