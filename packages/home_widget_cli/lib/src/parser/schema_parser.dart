import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';

/// Parses a Dart source file to extract [WidgetSpec]s.
Future<WidgetSpec?> parseSchemaSource(
  String source, {
  String? filePath,
}) async {
  final result = parseString(content: source, path: filePath);
  final unit = result.unit;

  for (final declaration in unit.declarations) {
    if (declaration is ClassDeclaration) {
      final spec = _parseClass(declaration);
      if (spec != null) {
        return spec;
      }
    }
  }

  return null;
}

WidgetSpec? _parseClass(ClassDeclaration classDecl) {
  for (final metadata in classDecl.metadata) {
    if (metadata.name.name == 'HomeWidget') {
      final args = metadata.arguments;
      if (args != null) {
        return _extractWidgetSpec(classDecl.name.lexeme, args);
      }
    }
  }
  return null;
}

WidgetSpec _extractWidgetSpec(String className, ArgumentList args) {
  String? name;
  String? dartOutput;
  HomeWidgetAndroidConfiguration? android;
  HomeWidgetIOSConfiguration? ios;
  List<DataFieldSpec> dataFields = [];
  InteractivitySpec? interactivity;

  for (final arg in args.arguments) {
    if (arg is NamedExpression) {
      final argName = arg.name.label.name;
      final expression = arg.expression;

      if (argName == 'name') {
        if (expression is StringLiteral) {
          name = expression.stringValue;
        }
      } else if (argName == 'dartOutput') {
        if (expression is StringLiteral) {
          dartOutput = expression.stringValue;
        }
      } else if (argName == 'data') {
        dataFields = _parseDataMap(expression);
      } else if (argName == 'android') {
        ArgumentList? configArgs;
        if (expression is InstanceCreationExpression) {
          configArgs = expression.argumentList;
        } else if (expression is MethodInvocation) {
          configArgs = expression.argumentList;
        }

        if (configArgs != null) {
          android = _extractAndroidConfig(configArgs);
        }
      } else if (argName == 'iOS') {
        ArgumentList? configArgs;
        if (expression is InstanceCreationExpression) {
          configArgs = expression.argumentList;
        } else if (expression is MethodInvocation) {
          configArgs = expression.argumentList;
        }

        if (configArgs != null) {
          ios = _extractIosConfig(configArgs);
        }
      } else if (argName == 'interactivity') {
        if (expression is InstanceCreationExpression) {
          String? importPath;
          String? callbackName;

          for (final arg in expression.argumentList.arguments) {
            if (arg is NamedExpression) {
              final name = arg.name.label.name;
              if (name == 'import') {
                importPath = arg.expression.toSource().replaceAll("'", "");
              } else if (name == 'callback') {
                callbackName = arg.expression.toSource().replaceAll("'", "");
              }
            }
          }

          if (importPath != null && callbackName != null) {
            interactivity =
                InteractivitySpec(import: importPath, callback: callbackName);
          }
        }
      }
    }
  }

  if (name == null) {
    throw FormatException(
      'Missing required argument "name" in @HomeWidget annotation on $className',
    );
  }

  return WidgetSpec(
    data: HomeWidget(
      name: name,
      dartOutput: dartOutput,
      android: android,
      iOS: ios,
    ),
    className: className,
    dataFields: dataFields,
    interactivity: interactivity,
  );
}

List<DataFieldSpec> _parseDataMap(Expression? dataExpr) {
  if (dataExpr == null) return [];
  if (dataExpr is! SetOrMapLiteral) {
    throw FormatException('data must be a Map literal');
  }
  return dataExpr.elements.map((element) {
    if (element is! MapLiteralEntry) {
      throw FormatException('data entries must be key: value pairs');
    }
    final keyNode = element.key;
    if (keyNode is! SimpleStringLiteral) {
      throw FormatException('data keys must be string literals');
    }
    final key = keyNode.value;

    final valueNode = element.value;
    String? typeName;
    if (valueNode is InstanceCreationExpression) {
      typeName = valueNode.constructorName.type.name2.lexeme;
    } else if (valueNode is MethodInvocation) {
      // Analyzer parses unknown constructors as MethodInvocation
      typeName = valueNode.methodName.name;
    } else {
      throw FormatException(
        'data values must be HWDataType constructors (found ${valueNode.runtimeType})',
      );
    }

    final type = switch (typeName) {
      'HWString' => HWDataFieldType.string,
      'HWInt' => HWDataFieldType.int_,
      'HWDouble' => HWDataFieldType.double_,
      'HWBool' => HWDataFieldType.bool_,
      _ => throw FormatException('Unknown data type: $typeName'),
    };
    return DataFieldSpec(key: key, type: type);
  }).toList();
}

HomeWidgetAndroidConfiguration? _extractAndroidConfig(ArgumentList args) {
  String? packageName;
  for (final arg in args.arguments) {
    if (arg is NamedExpression) {
      final argName = arg.name.label.name;
      if (argName == 'packageName') {
        final value = arg.expression;
        if (value is StringLiteral) {
          packageName = value.stringValue;
        }
      }
    }
  }
  return HomeWidgetAndroidConfiguration(packageName: packageName);
}

HomeWidgetIOSConfiguration? _extractIosConfig(ArgumentList args) {
  String? groupId;
  for (final arg in args.arguments) {
    if (arg is NamedExpression) {
      final argName = arg.name.label.name;
      if (argName == 'groupId') {
        final value = arg.expression;
        if (value is StringLiteral) {
          groupId = value.stringValue;
        }
      }
    }
  }

  if (groupId == null) {
    return null;
  }
  return HomeWidgetIOSConfiguration(groupId: groupId);
}
