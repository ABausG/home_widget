import 'package:home_widget_cli/src/generators/kotlin_widget_emitter.dart';
import 'package:home_widget_cli/src/models/widget_node.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:test/test.dart';

void main() {
  group('emitKotlinWidgetBody', () {
    test('emits fixed text', () {
      final node = TextNode(content: StaticValue('Hello'));
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(text = "Hello")');
    });

    test('emits string data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'label', type: HWDataFieldType.string),
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(text = data.label ?: "")');
    });

    test('emits int data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'count', type: HWDataFieldType.int_),
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(text = (data.count?.toString() ?: "0"))');
    });

    test('emits bool data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'flag', type: HWDataFieldType.bool_),
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(text = (data.flag?.toString() ?: "false"))');
    });

    test('emits double data ref', () {
      final node = TextNode(
        content: DataRefValue(key: 'ratio', type: HWDataFieldType.double_),
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(text = (data.ratio?.toString() ?: "0.0"))');
    });

    test('escapes strings', () {
      final node = TextNode(content: StaticValue('Price: \$5'));
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, 'Text(text = "Price: \\\$5")');
    });

    test('respects indent', () {
      final node = TextNode(content: StaticValue('Hello'));
      final result = emitKotlinWidgetBody(node, dataExpr: 'data', indent: 1);
      expect(result, '    Text(text = "Hello")');
    });
  });
}
