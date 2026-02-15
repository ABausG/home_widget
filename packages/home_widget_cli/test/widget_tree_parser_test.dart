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
