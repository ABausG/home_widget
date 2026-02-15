import 'package:analyzer/dart/ast/ast.dart';
import '../models/widget_node.dart';
import '../models/widget_spec.dart';
import '../generator_error.dart';

/// Parses a const widget expression into a platform-agnostic IR node.
///
/// [dataFields] is used to resolve HWText.data references: the data ref's
/// property name is looked up in the data map to determine the field type.
WidgetNode parseWidgetExpression(
  Expression expr, {
  required List<DataFieldSpec> dataFields,
}) {
  if (expr is! InstanceCreationExpression) {
    throw GeneratorError(
      'widgetBuilder must be a const constructor call, '
      'got ${expr.runtimeType}',
    );
  }

  var typeName = expr.constructorName.type.name2.lexeme; // e.g. 'HWText'
  var ctorName = expr.constructorName.name?.name; // e.g. 'fixed' or 'data'

  // When parsing "HWText.fixed(...)" without context, the analyzer may interprete
  // "HWText" as a prefix and "fixed" as a type.
  if (expr.constructorName.type.importPrefix != null &&
      ['HWText']
          .contains(expr.constructorName.type.importPrefix!.name.lexeme)) {
    typeName = expr.constructorName.type.importPrefix!.name.lexeme;
    ctorName = expr.constructorName.type.name2.lexeme;
  }

  return switch (typeName) {
    'HWText' => _parseHWText(expr, ctorName, dataFields: dataFields),
    // v4 will add: 'HWColumn' => ..., 'HWRow' => ...
    _ => throw GeneratorError('Unknown widget type: $typeName'),
  };
}

TextNode _parseHWText(
  InstanceCreationExpression expr,
  String? ctorName, {
  required List<DataFieldSpec> dataFields,
}) {
  return switch (ctorName) {
    'fixed' => _parseHWTextFixed(expr),
    'data' => _parseHWTextData(expr, dataFields: dataFields),
    _ => throw GeneratorError('Unknown HWText constructor: .$ctorName'),
  };
}

TextNode _parseHWTextFixed(InstanceCreationExpression expr) {
  final arg = expr.argumentList.arguments.first;
  if (arg is! SimpleStringLiteral) {
    throw GeneratorError('HWText.fixed() argument must be a string literal');
  }
  return TextNode(content: StaticValue(arg.value));
}

TextNode _parseHWTextData(
  InstanceCreationExpression expr, {
  required List<DataFieldSpec> dataFields,
}) {
  final arg = expr.argumentList.arguments.first;

  // exampleWidgetData.countLabel is a PrefixedIdentifier
  // where .identifier.name is 'countLabel'
  String fieldName;
  if (arg is PrefixedIdentifier) {
    fieldName = arg.identifier.name; // 'countLabel'
  } else if (arg is PropertyAccess) {
    fieldName = arg.propertyName.name;
  } else {
    throw GeneratorError(
      'HWText.data() argument must be a data ref '
      '(e.g. exampleWidgetData.fieldName)',
    );
  }

  // Look up the field in the data map to get its type
  final field = dataFields.where((f) => f.key == fieldName).firstOrNull;

  if (field == null) {
    throw GeneratorError(
      'HWText.data references unknown field "$fieldName". '
      'Declared fields: ${dataFields.map((f) => f.key).join(', ')}',
    );
  }

  return TextNode(
    content: DataRefValue(key: fieldName, type: field.type),
  );
}
