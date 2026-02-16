import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/widget_tree_parser.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('parseWidgetExpression with MethodInvocation', () {
    test('parses HWText.data without const', () {
      final expr =
          _parseClassMember("HWText.data(exampleWidgetData.countLabel)");

      final dataFields = [
        DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
      ];

      final node = parseWidgetExpression(expr, dataFields: dataFields);
      expect(node, isA<HWText>());
      final text = node as HWText;
      expect(
        text.toSwift(
          0,
          dataExpr: 'data',
          dataFields: {'countLabel': const HWString()},
        ),
        contains('data.countLabel'),
      );
    });

    test('parses HWText.fixed without const', () {
      final expr = _parseClassMember("HWText.fixed('Hello')");

      final node = parseWidgetExpression(expr, dataFields: []);
      expect(node, isA<HWText>());
      final text = node as HWText;
      expect(text.toSwift(0, dataExpr: 'data'), contains('Hello'));
    });
  });
}

// Helper for parsing class member expressions (copied from widget_tree_parser_test.dart)
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
