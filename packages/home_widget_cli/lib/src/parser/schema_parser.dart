// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';

import '../models/widget_spec.dart';
import '../validation/widget_data_validator.dart';

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

  final specs = <WidgetSpec>[];
  for (final element in result.libraryElement.classes) {
    if (_hasHomeWidgetAnnotation(element)) {
      final spec = _extractWidgetSpec(element);
      if (spec != null) {
        specs.add(spec);
      }
    }
  }
  return specs;
}

bool _isHomeWidgetAnnotation(ElementAnnotation meta) {
  final element = meta.element;
  return element is ConstructorElement &&
      element.enclosingElement.name == 'HomeWidget';
}

bool _hasHomeWidgetAnnotation(ClassElement element) {
  return element.metadata.annotations.any(_isHomeWidgetAnnotation);
}

WidgetSpec? _extractWidgetSpec(ClassElement element) {
  final annotation =
      element.metadata.annotations.firstWhere(_isHomeWidgetAnnotation);

  final constantValue = annotation.computeConstantValue();
  if (constantValue == null) return null;

  // Extract fields from the annotation object
  final name = constantValue.getField('name')?.toStringValue();
  final description = constantValue.getField('description')?.toStringValue();

  final generatedClassName = element.name;
  if (generatedClassName == null) return null;

  final dartOutput = constantValue.getField('dartOutput')?.toStringValue();

  final androidConfig =
      _extractAndroidConfig(constantValue.getField('android'));
  final iosConfig = _extractIosConfig(constantValue.getField('iOS'));

  // Widget Tree
  HWWidget? widgetTree;
  final widgetField = constantValue.getField('widget');
  if (widgetField != null && !widgetField.isNull) {
    widgetTree = WidgetValueDecoder(widgetField).decode();
  }

  // Data fields
  final dataFields = <HWDataType<dynamic>>[];
  if (widgetTree != null) {
    final dependencies = widgetTree.dataDependencies;
    for (final dep in dependencies) {
      dataFields.add(dep);
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
    ),
    className: generatedClassName,
    dataFields: dataFields,
    widgetTree: widgetTree,
  );
  validateWidgetData(spec);
  return spec;
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
  );
}

T? _decodeEnum<T>(DartObject? obj, List<T> values) {
  if (obj == null || obj.isNull) return null;
  final index = obj.getField('index')?.toIntValue();
  if (index != null && index >= 0 && index < values.length) {
    return values[index];
  }
  return null;
}
