import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_node.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/widget_tree_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseWidgetExpression', () {
    test('parses HWText.fixed', () {
      final expr = _parseClassMember("const HWText.fixed('Hello')");
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<TextNode>());
      final text = node as TextNode;
      expect(text.content, isA<StaticValue>());
      expect((text.content as StaticValue).value, 'Hello');
    });

    test('parses HWText.data', () {
      final expr =
          _parseClassMember("const HWText.data(exampleWidgetData.countLabel)");
      final dataFields = [
        DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
      ];
      final node = parseWidgetExpression(expr, dataFields: dataFields);
      expect(node, isA<TextNode>());
      final text = node as TextNode;
      expect(text.content, isA<DataRefValue>());
      final ref = text.content as DataRefValue;
      expect(ref.key, 'countLabel');
      expect(ref.type, HWDataFieldType.string);
    });

    test('throws on unknown data field', () {
      final expr =
          _parseClassMember("const HWText.data(exampleWidgetData.unknown)");
      expect(
        () => parseWidgetExpression(expr, dataFields: []),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws on unknown widget type', () {
      final expr = _parseClassMember("const UnknownWidget()");
      expect(
        () => parseWidgetExpression(expr, dataFields: []),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws on non-const constructor', () {
      final expr = _parseClassMember("new Text('Hi')");
      expect(
        () => parseWidgetExpression(expr, dataFields: []),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('parses simple HWColumn', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a'), HWText.fixed('b')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<ColumnNode>());
      final col = node as ColumnNode;
      expect(col.children, hasLength(2));
      expect(col.children[0], isA<TextNode>());
      expect(col.children[1], isA<TextNode>());
    });

    test('parses simple HWRow', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.fixed('x')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<RowNode>());
      final row = node as RowNode;
      expect(row.children, hasLength(1));
    });

    test('parses nested layout', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWRow(children: [HWText.fixed('x')])])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<ColumnNode>());
      final col = node as ColumnNode;
      expect(col.children.first, isA<RowNode>());
      final row = col.children.first as RowNode;
      expect(row.children.first, isA<TextNode>());
    });

    test('parses empty children', () {
      final expr = _parseClassMember("const HWColumn(children: [])");
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<ColumnNode>());
      expect((node as ColumnNode).children, isEmpty);
    });

    test('parses deep nesting (3+ levels)', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWRow(children: [HWColumn(children: [HWText.fixed('deep')])])])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as ColumnNode;
      final row = col.children.first as RowNode;
      final innerCol = row.children.first as ColumnNode;
      expect(innerCol.children.first, isA<TextNode>());
    });

    test('parses data ref in nested child', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.data(exampleWidgetData.countLabel)])",
      );
      final dataFields = [
        DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
      ];
      final node = parseWidgetExpression(expr, dataFields: dataFields);
      final col = node as ColumnNode;
      final text = col.children.first as TextNode;
      expect(text.content, isA<DataRefValue>());
      expect((text.content as DataRefValue).key, 'countLabel');
    });

    test('throws on unknown field in nested child', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.data(exampleWidgetData.nonExistent)])",
      );
      expect(
        () => parseWidgetExpression(expr, dataFields: []),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('parses mixed fixed + data in tree', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('Hi'), HWRow(children: [HWText.data(exampleWidgetData.count)])])",
      );
      final dataFields = [
        DataFieldSpec(key: 'count', type: HWDataFieldType.int_),
      ];
      final node = parseWidgetExpression(expr, dataFields: dataFields);
      final col = node as ColumnNode;
      expect(col.children[0], isA<TextNode>());
      final row = col.children[1] as RowNode;
      final dataText = row.children.first as TextNode;
      expect(dataText.content, isA<DataRefValue>());
    });

    test('parses crossAxisAlignment start', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')], crossAxisAlignment: HWCrossAxisAlignment.start)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as ColumnNode;
      expect(col.crossAxisAlignment, CrossAxisAlignment.start);
    });

    test('parses crossAxisAlignment center', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.fixed('a')], crossAxisAlignment: HWCrossAxisAlignment.center)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final row = node as RowNode;
      expect(row.crossAxisAlignment, CrossAxisAlignment.center);
    });

    test('no alignment defaults to null', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as ColumnNode;
      expect(col.crossAxisAlignment, isNull);
    });

    test('parses mainAxisAlignment center', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')], mainAxisAlignment: HWMainAxisAlignment.center)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as ColumnNode;
      expect(col.mainAxisAlignment, MainAxisAlignment.center);
    });

    test('parses mainAxisAlignment spaceBetween', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.fixed('a')], mainAxisAlignment: HWMainAxisAlignment.spaceBetween)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final row = node as RowNode;
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween);
    });

    test('no mainAxisAlignment defaults to null', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as ColumnNode;
      expect(col.mainAxisAlignment, isNull);
    });

    test('parses both cross and mainAxisAlignment', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')], crossAxisAlignment: HWCrossAxisAlignment.center, mainAxisAlignment: HWMainAxisAlignment.end)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as ColumnNode;
      expect(col.crossAxisAlignment, CrossAxisAlignment.center);
      expect(col.mainAxisAlignment, MainAxisAlignment.end);
    });
  });
}

// Helper for parsing class member expressions
Expression _parseClassMember(String source) {
  final code = '''
  class Test extends HomeWidgetBuilder {
    @override
    HWWidget get widgetBuilder => $source;
  }
  ''';
  final result = parseString(content: code);
  final classDecl = result.unit.declarations.first as ClassDeclaration;
  final method = classDecl.members.first as MethodDeclaration;
  final body = method.body as ExpressionFunctionBody;
  return body.expression;
}
