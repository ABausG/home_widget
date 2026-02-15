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
  String typeName;
  String? ctorName;

  if (expr is InstanceCreationExpression) {
    typeName = expr.constructorName.type.name2.lexeme;
    ctorName = expr.constructorName.name?.name;

    if (expr.constructorName.type.importPrefix != null &&
        ['HWText']
            .contains(expr.constructorName.type.importPrefix!.name.lexeme)) {
      typeName = expr.constructorName.type.importPrefix!.name.lexeme;
      ctorName = expr.constructorName.type.name2.lexeme;
    }
  } else if (expr is MethodInvocation) {
    // Handle cases like HWText.data(...) which are parsed as MethodInvocation
    // when not using const/new.
    final target = expr.target;
    if (target is SimpleIdentifier) {
      typeName = target.name;
      ctorName = expr.methodName.name;
    } else if (target == null) {
      // Nested constructor call without const/new, e.g. HWColumn(children: [...])
      // inside a const list literal. The method name is the type name.
      typeName = expr.methodName.name;
      ctorName = null;
    } else {
      throw GeneratorError(
        'Expected widget class name (e.g. HWText), got ${expr.target}',
      );
    }
  } else {
    throw GeneratorError(
      'widgetBuilder must be a const constructor call or method invocation, '
      'got ${expr.runtimeType}',
    );
  }

  return switch (typeName) {
    'HWText' => _parseHWText(expr, ctorName, dataFields: dataFields),
    'HWColumn' =>
      _parseLayoutNode(expr, isColumn: true, dataFields: dataFields),
    'HWRow' => _parseLayoutNode(expr, isColumn: false, dataFields: dataFields),
    _ => throw GeneratorError('Unknown widget type: $typeName'),
  };
}

TextNode _parseHWText(
  Expression expr,
  String? ctorName, {
  required List<DataFieldSpec> dataFields,
}) {
  final args = _getArguments(expr);
  return switch (ctorName) {
    'fixed' => _parseHWTextFixed(args),
    'data' => _parseHWTextData(args, dataFields: dataFields),
    _ => throw GeneratorError('Unknown HWText constructor: .$ctorName'),
  };
}

List<Expression> _getArguments(Expression expr) {
  if (expr is InstanceCreationExpression) {
    return expr.argumentList.arguments;
  } else if (expr is MethodInvocation) {
    return expr.argumentList.arguments;
  }
  throw GeneratorError('Unsupported expression type: ${expr.runtimeType}');
}

TextNode _parseHWTextFixed(List<Expression> args) {
  final arg = args.first;
  if (arg is! SimpleStringLiteral) {
    throw GeneratorError('HWText.fixed() argument must be a string literal');
  }
  return TextNode(content: StaticValue(arg.value));
}

TextNode _parseHWTextData(
  List<Expression> args, {
  required List<DataFieldSpec> dataFields,
}) {
  final arg = args.first;

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

WidgetNode _parseLayoutNode(
  Expression expr, {
  required bool isColumn,
  required List<DataFieldSpec> dataFields,
}) {
  final args = _getArguments(expr);

  final childrenArg = args.whereType<NamedExpression>().firstWhere(
        (a) => a.name.label.name == 'children',
        orElse: () => throw GeneratorError(
          '${isColumn ? "HWColumn" : "HWRow"} requires a children argument',
        ),
      );

  final listExpr = childrenArg.expression;
  if (listExpr is! ListLiteral) {
    throw GeneratorError('children must be a list literal');
  }

  final children = listExpr.elements.map((element) {
    if (element is! Expression) {
      throw GeneratorError(
        'children list elements must be expressions',
      );
    }
    return parseWidgetExpression(element, dataFields: dataFields);
  }).toList();

  final alignArg = args
      .whereType<NamedExpression>()
      .where((a) => a.name.label.name == 'crossAxisAlignment')
      .firstOrNull;

  final crossAxisAlignment =
      alignArg != null ? _parseCrossAxisAlignment(alignArg.expression) : null;

  final mainAlignArg = args
      .whereType<NamedExpression>()
      .where((a) => a.name.label.name == 'mainAxisAlignment')
      .firstOrNull;

  final mainAxisAlignment = mainAlignArg != null
      ? _parseMainAxisAlignment(mainAlignArg.expression)
      : null;

  return isColumn
      ? ColumnNode(
          children: children,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
        )
      : RowNode(
          children: children,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
        );
}

CrossAxisAlignment _parseCrossAxisAlignment(Expression expr) {
  final name = (expr as PrefixedIdentifier).identifier.name;
  return CrossAxisAlignment.values.firstWhere(
    (v) => v.name == name,
    orElse: () => throw GeneratorError('Unknown crossAxisAlignment: $name'),
  );
}

MainAxisAlignment _parseMainAxisAlignment(Expression expr) {
  final name = (expr as PrefixedIdentifier).identifier.name;
  return MainAxisAlignment.values.firstWhere(
    (v) => v.name == name,
    orElse: () => throw GeneratorError('Unknown mainAxisAlignment: $name'),
  );
}
