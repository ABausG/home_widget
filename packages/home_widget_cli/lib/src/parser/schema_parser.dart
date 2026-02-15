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
      } else if (argName == 'android') {
        if (expression is InstanceCreationExpression) {
          android = _extractAndroidConfig(expression);
        }
      } else if (argName == 'iOS') {
        if (expression is InstanceCreationExpression) {
          ios = _extractIosConfig(expression);
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
  );
}

HomeWidgetAndroidConfiguration? _extractAndroidConfig(
    InstanceCreationExpression expression) {
  String? packageName;
  for (final arg in expression.argumentList.arguments) {
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

HomeWidgetIOSConfiguration? _extractIosConfig(
    InstanceCreationExpression expression) {
  String? groupId;
  for (final arg in expression.argumentList.arguments) {
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
