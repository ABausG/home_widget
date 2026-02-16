import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/widget_tree_parser.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('parseWidgetExpression', () {
    test('parses HWText.fixed', () {
      final expr = _parseClassMember("const HWText.fixed('Hello')");
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<HWText>());
      // Fixed content is private, but checking type is enough for now,
      // or we can test generate output or rely on reflection if needed.
      // But for parser test, just checking type and structure is usually sufficient
      // if we can't access private fields.
      // Actually, we can't access private fields. Let's trust it parses.
      // Or we can rely on `toSwift/toKotlin` output if we really had to,
      // but that's what emitter tests are for.
      expect(node.toSwift(0, dataExpr: 'data'), contains('Text("Hello")'));
    });

    test('parses HWText.data', () {
      final expr =
          _parseClassMember("const HWText.data(exampleWidgetData.countLabel)");
      final dataFields = [
        DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
      ];
      final node = parseWidgetExpression(expr, dataFields: dataFields);
      expect(node, isA<HWText>());
      // Verify via output to indirectly check private fields
      expect(
        node.toSwift(
          0,
          dataExpr: 'data',
          dataFields: {'countLabel': const HWString()},
        ),
        contains('Text(data.countLabel ?? "")'),
      );
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
      expect(node, isA<HWColumn>());
      final col = node as HWColumn;
      expect(col.children, hasLength(2));
      expect(col.children[0], isA<HWText>());
      expect(col.children[1], isA<HWText>());
    });

    test('parses simple HWRow', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.fixed('x')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<HWRow>());
      final row = node as HWRow;
      expect(row.children, hasLength(1));
    });

    test('parses nested layout', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWRow(children: [HWText.fixed('x')])])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<HWColumn>());
      final col = node as HWColumn;
      expect(col.children.first, isA<HWRow>());
      final row = col.children.first as HWRow;
      expect(row.children.first, isA<HWText>());
    });

    test('parses empty children', () {
      final expr = _parseClassMember("const HWColumn(children: [])");
      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<HWColumn>());
      expect((node as HWColumn).children, isEmpty);
    });

    test('parses deep nesting (3+ levels)', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWRow(children: [HWColumn(children: [HWText.fixed('deep')])])])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as HWColumn;
      final row = col.children.first as HWRow;
      final innerCol = row.children.first as HWColumn;
      expect(innerCol.children.first, isA<HWText>());
    });

    test('parses data ref in nested child', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.data(exampleWidgetData.countLabel)])",
      );
      final dataFields = [
        DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
      ];
      final node = parseWidgetExpression(expr, dataFields: dataFields);
      final col = node as HWColumn;
      final text = col.children.first as HWText;
      expect(text, isA<HWText>());
      // Indirect verification
      expect(
        text.toSwift(
          0,
          dataExpr: 'data',
          dataFields: {'countLabel': const HWString()},
        ),
        contains('Text(data.countLabel ?? "")'),
      );
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
      final col = node as HWColumn;
      expect(col.children[0], isA<HWText>());
      final row = col.children[1] as HWRow;
      final dataText = row.children.first as HWText;
      expect(
        dataText.toSwift(
          0,
          dataExpr: 'data',
          dataFields: {'count': const HWInt()},
        ),
        contains('Text(data.count != nil'),
      );
    });

    test('parses crossAxisAlignment start', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')], crossAxisAlignment: HWCrossAxisAlignment.start)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as HWColumn;
      expect(col.crossAxisAlignment, HWCrossAxisAlignment.start);
    });

    test('parses crossAxisAlignment center', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.fixed('a')], crossAxisAlignment: HWCrossAxisAlignment.center)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final row = node as HWRow;
      expect(row.crossAxisAlignment, HWCrossAxisAlignment.center);
    });

    test('no alignment defaults to null', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as HWColumn;
      expect(col.crossAxisAlignment, isNull);
    });

    test('parses mainAxisAlignment center', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')], mainAxisAlignment: HWMainAxisAlignment.center)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as HWColumn;
      expect(col.mainAxisAlignment, HWMainAxisAlignment.center);
    });

    test('parses mainAxisAlignment spaceBetween', () {
      final expr = _parseClassMember(
        "const HWRow(children: [HWText.fixed('a')], mainAxisAlignment: HWMainAxisAlignment.spaceBetween)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final row = node as HWRow;
      expect(row.mainAxisAlignment, HWMainAxisAlignment.spaceBetween);
    });

    test('no mainAxisAlignment defaults to null', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')])",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as HWColumn;
      expect(col.mainAxisAlignment, isNull);
    });

    test('parses both cross and mainAxisAlignment', () {
      final expr = _parseClassMember(
        "const HWColumn(children: [HWText.fixed('a')], crossAxisAlignment: HWCrossAxisAlignment.center, mainAxisAlignment: HWMainAxisAlignment.end)",
      );
      final node = parseWidgetExpression(expr, dataFields: []);
      final col = node as HWColumn;
      expect(col.crossAxisAlignment, HWCrossAxisAlignment.center);
      expect(col.mainAxisAlignment, HWMainAxisAlignment.end);
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
