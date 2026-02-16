import 'package:home_widget_cli/src/generators/kotlin_widget_emitter.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('emitKotlinWidgetBody', () {
    test('emits fixed text', () {
      final node = HWText.fixed('Hello');
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, 'Text(text = "Hello")');
    });

    test('emits string data ref', () {
      final node = HWText.data(HWDataRef('label'));
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'label', type: HWDataFieldType.string),
        ],
      );
      expect(result, 'Text(text = data.label ?: "")');
    });

    test('emits int data ref', () {
      final node = HWText.data(HWDataRef('count'));
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'count', type: HWDataFieldType.int_),
        ],
      );
      expect(result, 'Text(text = (data.count?.toString() ?: "0"))');
    });

    test('emits bool data ref', () {
      final node = HWText.data(HWDataRef('flag'));
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'flag', type: HWDataFieldType.bool_),
        ],
      );
      expect(result, 'Text(text = (data.flag?.toString() ?: "false"))');
    });

    test('emits double data ref', () {
      final node = HWText.data(HWDataRef('ratio'));
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'ratio', type: HWDataFieldType.double_),
        ],
      );
      expect(result, 'Text(text = (data.ratio?.toString() ?: "0.0"))');
    });

    test('escapes strings', () {
      final node = HWText.fixed('Price: \$5');
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, 'Text(text = "Price: \\\$5")');
    });

    test('respects indent', () {
      final node = HWText.fixed('Hello');
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [],
        indent: 1,
      );
      expect(result, '    Text(text = "Hello")');
    });

    test('Column from HWColumn', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
          HWText.fixed('b'),
        ],
      );
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('Column {'));
      expect(result, contains('Row {'));
      expect(result, contains('Text(text = "x")'));
      expect(result, contains('Text(text = "y")'));
    });

    test('data in layout', () {
      final node = HWColumn(
        children: [
          HWText.data(HWDataRef('count')),
        ],
      );
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [
          DataFieldSpec(key: 'count', type: HWDataFieldType.string),
        ],
      );
      expect(result, contains('Column {'));
      expect(result, contains('Text(text = data.count ?: "")'));
    });

    test('empty Column', () {
      final node = HWColumn(children: []);
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('Column {'));
      expect(result, contains('}'));
    });

    test('layout indentation', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('x')]),
        ],
      );
      final result = emitKotlinWidgetBody(
        node,
        dataExpr: 'data',
        dataFields: [],
        indent: 0,
      );
      expect(result, startsWith('Column {'));
      expect(result, contains('    Row {'));
      expect(result, contains('        Text(text = "x")'));
    });
  });

  group('collectKotlinLayoutImports', () {
    test('Column in tree', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Column'));
    });

    test('Row in tree', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('both Column + Row', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('a')]),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Column'));
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('HWText only', () {
      final node = HWText.fixed('a');
      final imports = collectKotlinLayoutImports(node);
      expect(imports, isEmpty);
    });

    test('null tree', () {
      final imports = collectKotlinLayoutImports(null);
      expect(imports, isEmpty);
    });

    test('alignment import when alignment is set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.compose.ui.Alignment'));
    });
  });

  group('alignment emitter', () {
    test('Column with .center alignment', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('Row(verticalAlignment = Alignment.Top) {'));
    });

    test('no alignment emits bare layout', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(result, contains('Column {'));
      expect(result, isNot(contains('horizontalAlignment')));
    });
  });

  group('mainAxisAlignment emitter', () {
    test('Column with .center emits Spacer before and after', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
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
      final result =
          emitKotlinWidgetBody(node, dataExpr: 'data', dataFields: []);
      expect(
        result,
        contains('horizontalAlignment = Alignment.CenterHorizontally'),
      );
      expect(result, contains('Spacer()'));
      // end = 1 spacer before children
      expect('Spacer()'.allMatches(result).length, 1);
    });

    test('Spacer import collected when mainAxisAlignment set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Spacer'));
    });

    test('no Spacer import when mainAxisAlignment not set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(
        imports,
        isNot(contains('import androidx.glance.layout.Spacer')),
      );
    });
  });
}
