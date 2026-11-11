// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';

import '../models/widget_spec.dart';
import '../util/naming.dart';
import '../validation/widget_data_validator.dart';
import 'interaction_handler_parser.dart';

/// Parses a Dart source file to extract [WidgetSpec]s using Analyzer resolution.
Future<List<WidgetSpec>> parseSchemaFile(
  String filePath, {
  AnalysisContextCollection? collection,
}) async {
  final ensureCollection = collection ??
      AnalysisContextCollection(
        includedPaths: [filePath],
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );

  final context = ensureCollection.contextFor(filePath);
  final result = await context.currentSession.getResolvedUnit(filePath);

  if (result is! ResolvedUnitResult) {
    // coverage:ignore-start
    throw FormatException('Failed to resolve unit for $filePath');
    // coverage:ignore-end
  }

  await _rejectBrokenAnnotations(result, filePath);

  final specs = <WidgetSpec>[];
  for (final element in result.libraryElement.classes) {
    if (_hasHomeWidgetAnnotation(element)) {
      final spec = _extractWidgetSpec(element, filePath);
      if (spec != null) {
        specs.add(spec);
      }
    }
  }
  return specs;
}

/// Where the migration guides of `home_widget_generator` start.
const String generatorMigrationGuideUrl =
    'https://docs.page/ABausG/home_widget/generator/migrations/0.5.0';

/// Fails when the analyzer reports an error inside a `@HomeWidget(...)`
/// annotation of [result]: a parameter, constructor or widget that does not
/// exist, or a value that is no constant.
///
/// The analyzer still evaluates such an annotation, leaving out what it could
/// not resolve, so the widget would be generated from something other than
/// what the schema says. The same goes for a `const` variable of the project
/// the annotation refers to, and for the ones that refers to in turn. Errors
/// anywhere else are left alone: a schema may sit next to code that only
/// compiles once the helpers exist.
Future<void> _rejectBrokenAnnotations(
  ResolvedUnitResult result,
  String filePath,
) async {
  for (final declaration in result.unit.declarations) {
    for (final annotation in declaration.metadata) {
      if (annotation.name.name.split('.').last != 'HomeWidget') continue;

      final lines = [
        ..._problemsIn(annotation, result),
        ...await _problemsInReferencedConstants(annotation, result),
      ];
      if (lines.isEmpty) continue;

      final inOnInteraction = [...?annotation.arguments?.arguments]
          .where((argument) => _onInteractionArgument.hasMatch('$argument'))
          .any((argument) => _problemsIn(argument, result).isNotEmpty);
      throw GeneratorError(
        '$filePath: the @HomeWidget annotation does not compile, so no widget '
        'can be generated from it:\n'
        '${lines.join('\n')}\n'
        '${inOnInteraction ? '${_onInteractionHint.trim()}\n' : ''}'
        'A parameter, constructor or widget that a newer '
        'home_widget_generator removed is listed with its replacement in the '
        'migration guides: $generatorMigrationGuideUrl',
      );
    }
  }
}

final RegExp _onInteractionArgument = RegExp(r'^onInteraction\s*:');

/// What to pass as `onInteraction`, for an annotation that is no constant.
const String _onInteractionHint =
    ' onInteraction has to be a compile-time constant: pass a top-level or '
    'static function by name, e.g. onInteraction: onCounterInteraction.';

/// The errors the analyzer reports inside [node], a node of [unit], one line
/// each, located by line and column and by [origin] where given.
List<String> _problemsIn(
  AstNode node,
  ResolvedUnitResult unit, {
  String origin = '',
}) =>
    [
      for (final diagnostic in unit.diagnostics)
        if (diagnostic.severity == Severity.error &&
            diagnostic.offset >= node.offset &&
            diagnostic.offset < node.end)
          () {
            final location = unit.lineInfo.getLocation(diagnostic.offset);
            return '  $origin${location.lineNumber}:${location.columnNumber}: '
                '${diagnostic.message}';
          }(),
    ];

/// The errors inside the declaration of every `const` variable [root], a node
/// of [unit], refers to, directly or through another such variable.
///
/// Only variables declared in a file of the project are looked at: one of a
/// package is not the schema author's to fix.
Future<List<String>> _problemsInReferencedConstants(
  AstNode root,
  ResolvedUnitResult unit,
) async {
  final lines = <String>[];
  final seen = <PropertyInducingElement>{};
  final units = <String, ResolvedUnitResult?>{unit.path: unit};
  final pending = <AstNode>[root];

  while (pending.isNotEmpty) {
    final references = _ConstantReferences();
    pending.removeLast().accept(references);

    for (final variable in references.variables) {
      if (!seen.add(variable)) continue;
      final path = variable.firstFragment.libraryFragment.source.fullName;
      if (!units.containsKey(path)) {
        final context = unit.session.analysisContext;
        final resolved = context.contextRoot.isAnalyzed(path)
            ? await unit.session.getResolvedUnit(path)
            : null;
        units[path] = resolved is ResolvedUnitResult ? resolved : null;
      }
      final declaring = units[path];
      if (declaring == null) continue;

      final finder = _VariableDeclarationFinder(variable);
      declaring.unit.accept(finder);
      final declaration = finder.declaration;
      // An enum value is no variable declaration.
      if (declaration == null) continue; // coverage:ignore-line

      final file = path == unit.path ? '' : '$path:';
      lines.addAll(
        _problemsIn(
          declaration,
          declaring,
          origin: 'const ${variable.name}, $file',
        ),
      );
      pending.add(declaration);
    }
  }
  return lines;
}

/// Collects the top-level and static `const` variables a node refers to.
class _ConstantReferences extends RecursiveAstVisitor<void> {
  final List<PropertyInducingElement> variables = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is GetterElement) {
      final variable = element.variable;
      final shared = variable is TopLevelVariableElement ||
          (variable is FieldElement && variable.isStatic);
      if (variable.isConst && shared) variables.add(variable);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Finds the declaration of [variable] in the unit it visits.
class _VariableDeclarationFinder extends RecursiveAstVisitor<void> {
  final PropertyInducingElement variable;

  VariableDeclaration? declaration;

  _VariableDeclarationFinder(this.variable);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.declaredFragment?.element == variable) declaration = node;
    super.visitVariableDeclaration(node);
  }
}

bool _isHomeWidgetAnnotation(ElementAnnotation meta) {
  final element = meta.element;
  return element is ConstructorElement &&
      element.enclosingElement.name == 'HomeWidget';
}

bool _hasHomeWidgetAnnotation(ClassElement element) {
  return element.metadata.annotations.any(_isHomeWidgetAnnotation);
}

WidgetSpec? _extractWidgetSpec(ClassElement element, String filePath) {
  final annotation =
      element.metadata.annotations.firstWhere(_isHomeWidgetAnnotation);

  final constantValue = annotation.computeConstantValue();
  if (constantValue == null) {
    // coverage:ignore-start
    throw GeneratorError(
      '$filePath: the @HomeWidget annotation of ${element.name} is not a '
      'compile-time constant, so no widget can be generated from it. Every '
      'value it uses has to be a constant.$_onInteractionHint',
    );
    // coverage:ignore-end
  }

  // Extract fields from the annotation object
  final name = constantValue.getField('name')?.toStringValue();
  final description = constantValue.getField('description')?.toStringValue();

  final generatedClassName = element.name;
  if (generatedClassName == null) return null;

  final dartOutput = constantValue.getField('dartOutput')?.toStringValue();

  final androidConfig =
      _extractAndroidConfig(constantValue.getField('android'));
  final iosConfig = _extractIosConfig(constantValue.getField('iOS'));

  final localization =
      _extractLocalization(constantValue.getField('localization'));

  // Widget Tree
  HWWidget? widgetTree;
  final widgetField = constantValue.getField('widget');
  if (widgetField != null && !widgetField.isNull) {
    widgetTree = WidgetValueDecoder(
      widgetField,
      defaultLocale: localization?.defaultLocale,
      resourcePrefix: widgetResourcePrefix(generatedClassName),
      fontResourcePrefix: hwFontResourcePrefix(toSnakeCase(generatedClassName)),
    ).decode();
  }

  final widgetUrlData = WidgetValueDecoder.decodePayload(
    constantValue.getField('widgetUrlData'),
    owner: 'widgetUrlData',
    defaultLocale: localization?.defaultLocale,
    resourcePrefix: widgetResourcePrefix(generatedClassName),
  );

  // Data fields
  final dataFields = <HWDataType<dynamic>>[];
  if (widgetTree != null) {
    final dependencies = widgetTree.dataDependencies;
    for (final dep in dependencies) {
      dataFields.add(dep);
    }
  }
  // The widget reads what its URL sends along, shown or not.
  for (final entry in HWPayloadEntry.listOf(widgetUrlData)) {
    if (entry.value.isDataDependency && !dataFields.contains(entry.value)) {
      dataFields.add(entry.value);
    }
  }

  if (name == null) return null;

  final spec = WidgetSpec(
    data: HomeWidget(
      name: name,
      description: description,
      widget: widgetTree,
      dartOutput: dartOutput,
      android: androidConfig,
      iOS: iosConfig,
      localization: localization,
      widgetUrl: constantValue.getField('widgetUrl')?.toStringValue(),
      widgetUrlData: widgetUrlData,
      flavors: _extractFlavors(constantValue.getField('flavors')),
      useLiveDataInPreview:
          constantValue.getField('useLiveDataInPreview')?.toBoolValue() ?? true,
    ),
    className: generatedClassName,
    dataFields: dataFields,
    widgetTree: widgetTree,
    interactionHandler: parseInteractionHandler(
      annotationValue: constantValue,
      widgetName: name,
      interactionClassName: '${generatedClassName}Interaction',
    ),
  );
  validateWidgetData(spec);
  return spec;
}

HomeWidgetLocalization? _extractLocalization(DartObject? obj) {
  if (obj == null || obj.isNull) return null;

  final defaultLocale = obj.getField('defaultLocale')?.toStringValue();
  if (defaultLocale == null) return null;

  final supported = obj
          .getField('supportedLocales')
          ?.toListValue()
          ?.map((e) => e.toStringValue())
          .whereType<String>()
          .toList() ??
      const <String>[];

  return HomeWidgetLocalization(
    defaultLocale: defaultLocale,
    supportedLocales: supported,
    name: WidgetValueDecoder.decodeStringMap(obj.getField('name')),
    description:
        WidgetValueDecoder.decodeStringMap(obj.getField('description')),
  );
}

HomeWidgetAndroidConfiguration? _extractAndroidConfig(DartObject? obj) {
  // obj is DartObject?
  if (obj == null || obj.isNull) return null;

  // We can read fields directly
  return HomeWidgetAndroidConfiguration(
    packageName: obj.getField('packageName')?.toStringValue(),
    minWidth: obj.getField('minWidth')?.toIntValue(),
    minHeight: obj.getField('minHeight')?.toIntValue(),
    minResizeWidth: obj.getField('minResizeWidth')?.toIntValue(),
    minResizeHeight: obj.getField('minResizeHeight')?.toIntValue(),
    maxResizeWidth: obj.getField('maxResizeWidth')?.toIntValue(),
    maxResizeHeight: obj.getField('maxResizeHeight')?.toIntValue(),
    targetCellWidth: obj.getField('targetCellWidth')?.toIntValue(),
    targetCellHeight: obj.getField('targetCellHeight')?.toIntValue(),
    resizeMode:
        _decodeEnum(obj.getField('resizeMode'), HWAndroidResizeMode.values),
    widgetCategory: _decodeEnum(
      obj.getField('widgetCategory'),
      HWAndroidWidgetCategory.values,
    ),
    updatePeriodMillis: obj.getField('updatePeriodMillis')?.toIntValue(),
    backgroundColor:
        WidgetValueDecoder.decodeColor(obj.getField('backgroundColor')),
    applyContentPadding:
        obj.getField('applyContentPadding')?.toBoolValue() ?? true,
    fillWidgetContent: obj.getField('fillWidgetContent')?.toBoolValue() ?? true,
    openAppOnTap: obj.getField('openAppOnTap')?.toBoolValue() ?? true,
    // Nullable on purpose: unset inherits the top-level value.
    useLiveDataInPreview: obj.getField('useLiveDataInPreview')?.toBoolValue(),
    autoUpdatePreview: obj.getField('autoUpdatePreview')?.toBoolValue() ?? true,
  );
}

HomeWidgetIOSConfiguration? _extractIosConfig(DartObject? obj) {
  if (obj == null || obj.isNull) return null;

  final groupId = obj.getField('groupId')?.toStringValue();
  if (groupId == null) return null;

  final familiesObj = obj.getField('supportedFamilies')?.toListValue();
  final families = familiesObj
      ?.map((f) => _decodeEnum(f, HWWidgetFamily.values))
      .whereType<HWWidgetFamily>()
      .toList();

  return HomeWidgetIOSConfiguration(
    groupId: groupId,
    supportedFamilies: families,
    backgroundColor: WidgetValueDecoder.decodeColor(
      obj.getField('backgroundColor'),
    ),
    applyContentPadding:
        obj.getField('applyContentPadding')?.toBoolValue() ?? true,
    useLiveDataInPreview: obj.getField('useLiveDataInPreview')?.toBoolValue(),
    provisioningProfile: obj.getField('provisioningProfile')?.toStringValue(),
  );
}

Map<String, HomeWidgetFlavor>? _extractFlavors(DartObject? obj) {
  if (obj == null || obj.isNull) return null;

  final entries = obj.toMapValue();
  if (entries == null) return null;

  final flavors = <String, HomeWidgetFlavor>{};
  for (final entry in entries.entries) {
    final name = entry.key?.toStringValue();
    if (name == null) continue;
    flavors[name] = _extractFlavor(entry.value);
  }
  return flavors;
}

HomeWidgetFlavor _extractFlavor(DartObject? obj) {
  if (obj == null || obj.isNull) return const HomeWidgetFlavor();

  return HomeWidgetFlavor(iOS: _extractIosFlavor(obj.getField('iOS')));
}

HomeWidgetIOSFlavor? _extractIosFlavor(DartObject? obj) {
  if (obj == null || obj.isNull) return null;

  return HomeWidgetIOSFlavor(
    groupId: obj.getField('groupId')?.toStringValue(),
    provisioningProfile: obj.getField('provisioningProfile')?.toStringValue(),
  );
}

/// The constant [obj] names, matched against [values] by name.
///
/// The name survives a member being inserted into the annotation's enum ahead
/// of the one written, which the declaration index does not.
T? _decodeEnum<T>(DartObject? obj, List<T> values) {
  if (obj == null || obj.isNull) return null;

  final name = obj.variable?.name;
  for (final value in values) {
    if (value is Enum && value.name == name) return value;
  }

  final index = obj.getField('index')?.toIntValue();
  if (index != null && index >= 0 && index < values.length) {
    return values[index];
  }
  return null;
}
