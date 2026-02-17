import 'package:home_widget_generator/home_widget_generator.dart';
import '../models/widget_spec.dart';

/// Emits SwiftUI view code from a HWWidget tree.
///
/// [dataExpr] is the Swift expression to access data fields.
/// [dataFields] is the list of fields defined in the widget spec.
String emitSwiftWidgetBody(
  HWWidget node, {
  required String dataExpr,
  required List<DataFieldSpec> dataFields,
  int indent = 0,
}) {
  final fieldMap = {
    for (final field in dataFields)
      field.key: _toHWDataType(field.key, field.type),
  };

  return node.toSwift(indent, dataExpr: dataExpr, dataFields: fieldMap);
}

HWDataType _toHWDataType(String key, HWDataFieldType type) {
  return switch (type) {
    HWDataFieldType.string => HWString(key),
    HWDataFieldType.int_ => HWInt(key),
    HWDataFieldType.double_ => HWDouble(key),
    HWDataFieldType.bool_ => HWBool(key),
  };
}
