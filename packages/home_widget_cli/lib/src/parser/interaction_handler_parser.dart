// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';

/// The function the `onInteraction` of the evaluated `@HomeWidget` annotation
/// [annotationValue] names, or null when the annotation sets none.
///
/// [widgetName] is the widget an error names and [interactionClassName] the
/// generated class the function is called with.
///
/// Throws a [GeneratorError] for a function the generated Dart cannot call.
/// The class the function takes is generated, so it does not resolve before
/// the first run: a parameter whose type does not resolve is accepted, and
/// only one of another type is rejected.
InteractionHandler? parseInteractionHandler({
  required DartObject annotationValue,
  required String widgetName,
  required String interactionClassName,
}) {
  final where = 'Widget "$widgetName": onInteraction';
  final function = annotationValue.getField('onInteraction')?.toFunctionValue();
  if (function == null) return null;

  final enclosing = function.enclosingElement;
  final className = enclosing is LibraryElement ? null : enclosing?.name;
  final isStaticFunction = function is TopLevelFunctionElement ||
      (function is MethodElement && function.isStatic);
  final name = function.name;
  if (!isStaticFunction || name == null) {
    throw GeneratorError(
      '$where names ${function.displayName}, which is not a top-level or '
      'static function. The widget runs it without an instance of anything, '
      'so use a top-level or static function.',
    );
  }
  final reference = className == null ? name : '$className.$name';
  if (name.startsWith('_') || (className?.startsWith('_') ?? false)) {
    throw GeneratorError(
      '$where names $reference, which is private. The generated Dart calls '
      'it from a library of its own, so make it public.',
    );
  }

  final library = function.library.uri;
  if (library.scheme != 'package') {
    throw GeneratorError(
      '$where names $reference, declared in $library. The generated Dart '
      'has to import it, so declare it in a library under lib/ and import '
      'that library in the schema file.',
    );
  }

  final parameters = function.formalParameters;
  if (parameters.length != 1 || !parameters.single.isPositional) {
    throw GeneratorError(
      '$where names $reference, which has to take exactly one positional '
      'parameter: the $interactionClassName that was tapped.',
    );
  }

  final returnType = function.returnType.getDisplayString();
  if (returnType != 'Future<void>') {
    throw GeneratorError(
      '$where names $reference, which returns $returnType. Return '
      'Future<void>: the tap waits for it to finish.',
    );
  }

  final parameterType = parameters.single.type;
  if (!_takes(parameterType, interactionClassName)) {
    throw GeneratorError(
      '$where names $reference, whose parameter is a '
      '${parameterType.getDisplayString()}. It is called with the generated '
      '$interactionClassName, so take that.',
    );
  }

  return InteractionHandler(
    libraryUri: '$library',
    name: name,
    className: className,
  );
}

/// Whether a parameter of [type] can be handed the generated class
/// [interactionClassName]: it is that class, also behind a typedef, `Object`,
/// `dynamic`, or a type that does not resolve yet.
bool _takes(DartType type, String interactionClassName) =>
    type is DynamicType ||
    type is InvalidType ||
    type.isDartCoreObject ||
    type.element?.name == interactionClassName;
