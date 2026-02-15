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

    test('Column from ColumnNode', () {
      final node = ColumnNode(
        children: [
          TextNode(content: StaticValue('a')),
          TextNode(content: StaticValue('b')),
        ],
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('Text(text = "a")'));
      expect(result, contains('Text(text = "b")'));
    });

    test('Row from RowNode', () {
      final node = RowNode(
        children: [
          TextNode(content: StaticValue('x')),
        ],
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "x")'));
    });

    test('nested Column/Row', () {
      final node = ColumnNode(
        children: [
          RowNode(children: [TextNode(content: StaticValue('x'))]),
          TextNode(content: StaticValue('y')),
        ],
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "x")'));
      expect(result, contains('Text(text = "y")'));
    });

    test('data in layout', () {
      final node = ColumnNode(
        children: [
          TextNode(
            content: DataRefValue(key: 'count', type: HWDataFieldType.string),
          ),
        ],
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('Text(text = data.count ?: "")'));
    });

    test('empty Column', () {
      final node = ColumnNode(children: []);
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = ColumnNode(
        children: [
          RowNode(children: [TextNode(content: StaticValue('x'))]),
        ],
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data', indent: 0);
      expect(result, startsWith('Column {'));
      expect(result, contains('    Row {'));
      expect(result, contains('        Text(text = "x")'));
    });
  });

  group('collectKotlinLayoutImports', () {
    test('Column in tree', () {
      final node = ColumnNode(
        children: [
          TextNode(content: StaticValue('a')),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Column'));
    });

    test('Row in tree', () {
      final node = RowNode(
        children: [
          TextNode(content: StaticValue('a')),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('both Column + Row', () {
      final node = ColumnNode(
        children: [
          RowNode(children: [TextNode(content: StaticValue('a'))]),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Column'));
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('TextNode only', () {
      final node = TextNode(content: StaticValue('a'));
      final imports = collectKotlinLayoutImports(node);
      expect(imports, isEmpty);
    });

    test('null tree', () {
      final imports = collectKotlinLayoutImports(null);
      expect(imports, isEmpty);
    });

    test('alignment import when alignment is set', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.center,
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.compose.ui.Alignment'));
    });
  });

  group('alignment emitter', () {
    test('Column with .center alignment', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.center,
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(
        result,
        contains(
          'Column(horizontalAlignment = Alignment.CenterHorizontally) {',
        ),
      );
    });

    test('Row with .start alignment', () {
      final node = RowNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.start,
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Row(verticalAlignment = Alignment.Top) {'));
    });

    test('no alignment emits bare layout', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, isNot(contains('horizontalAlignment')));
    });
  });

  group('mainAxisAlignment emitter', () {
    test('Column with .center emits Spacer before and after', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        mainAxisAlignment: MainAxisAlignment.center,
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Column {'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text(text = "a")'));
      expect('Spacer()'.allMatches(result).length, 2);
    });

    test('Row with .spaceBetween emits Spacer between children', () {
      final node = RowNode(
        children: [
          TextNode(content: StaticValue('a')),
          TextNode(content: StaticValue('b')),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "a")'));
      expect(result, contains('Spacer()'));
      expect(result, contains('Text(text = "b")'));
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Column with both cross and main alignment', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
      );
      final result = emitKotlinWidgetBody(node, dataExpr: 'data');
      expect(
        result,
        contains('horizontalAlignment = Alignment.CenterHorizontally'),
      );
      expect(result, contains('Spacer()'));
      // end = 1 spacer before children
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Spacer import collected when mainAxisAlignment set', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
        mainAxisAlignment: MainAxisAlignment.center,
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Spacer'));
    });

    test('no Spacer import when mainAxisAlignment not set', () {
      final node = ColumnNode(
        children: [TextNode(content: StaticValue('a'))],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(
        imports,
        isNot(contains('import androidx.glance.layout.Spacer')),
      );
    });
  });
}
