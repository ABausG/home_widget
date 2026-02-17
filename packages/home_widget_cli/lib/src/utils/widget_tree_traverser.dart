import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';

/// Traverses the [HWWidget] tree to extract [DataFieldSpec]s.
class WidgetTreeTraverser {
  /// Extracts all [DataFieldSpec]s defined in the [HWWidget] tree.
  static List<DataFieldSpec> extractDataFields(HWWidget root) {
    final fields = <String, DataFieldSpec>{};
    _traverse(root, fields);
    return fields.values.toList();
  }

  static void _traverse(
    HWWidget node,
    Map<String, DataFieldSpec> collectedFields,
  ) {
    switch (node) {
      case HWMultiChildWidget(:final children):
        for (final child in children) {
          _traverse(child, collectedFields);
        }
      case HWDataWidget(:final dataDependencies):
        for (final data in dataDependencies) {
          _addField(data, collectedFields);
        }
    }
  }

  static void _addField(
    HWDataType type,
    Map<String, DataFieldSpec> collectedFields,
  ) {
    if (type.key == null) return;
    final fieldType = _mapType(type);
    // If the field is already collected, we assume it's the same type.
    // In a real generic implementation we might want to validate type consistency.
    collectedFields.putIfAbsent(
      type.key!,
      () => DataFieldSpec(key: type.key!, type: fieldType),
    );
  }

  static HWDataFieldType _mapType(HWDataType type) {
    return switch (type) {
      HWString() => HWDataFieldType.string,
      HWInt() => HWDataFieldType.int_,
      HWDouble() => HWDataFieldType.double_,
      HWBool() => HWDataFieldType.bool_,
      _ => throw ArgumentError('Unknown HWDataType: $type'),
    };
  }
}
