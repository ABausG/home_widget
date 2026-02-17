import 'package:home_widget_generator/home_widget_generator.dart';
import '../models/widget_spec.dart';

/// Emits Jetpack Glance Composable code from a HWWidget tree.
///
/// [dataExpr] is the Kotlin expression to access data fields.
/// [dataFields] is the list of fields defined in the widget spec.
String emitKotlinWidgetBody(
  HWWidget node, {
  required String dataExpr,
  required List<DataFieldSpec> dataFields,
  int indent = 0,
}) {
  final fieldMap = {
    for (final field in dataFields)
      field.key: _toHWDataType(field.key, field.type),
  };

  return node.toKotlin(indent, dataExpr: dataExpr, dataFields: fieldMap);
}

/// Returns the set of Glance layout imports needed for the widget tree.
Set<String> collectKotlinLayoutImports(HWWidget? node) {
  if (node == null) return {};
  final imports = <String>{};
  _walkForImports(node, imports);
  return imports;
}

void _walkForImports(HWWidget node, Set<String> imports) {
  switch (node) {
    case HWColumn(
        :final children,
        :final crossAxisAlignment,
        :final mainAxisAlignment,
      ):
      imports.add('import androidx.glance.layout.Column');
      if (crossAxisAlignment != null) {
        imports.add('import androidx.compose.ui.Alignment');
      }
      if (mainAxisAlignment != null) {
        imports.add('import androidx.glance.layout.Spacer');
      }
      for (final child in children) {
        _walkForImports(child, imports);
      }
    case HWRow(
        :final children,
        :final crossAxisAlignment,
        :final mainAxisAlignment,
      ):
      imports.add('import androidx.glance.layout.Row');
      if (crossAxisAlignment != null) {
        imports.add('import androidx.compose.ui.Alignment');
      }
      if (mainAxisAlignment != null) {
        imports.add('import androidx.glance.layout.Spacer');
      }
      for (final child in children) {
        _walkForImports(child, imports);
      }
    case HWText():
      break;
    case HWDataOnly():
      break;
  }
}

HWDataType _toHWDataType(String key, HWDataFieldType type) {
  return switch (type) {
    HWDataFieldType.string => HWString(key),
    HWDataFieldType.int_ => HWInt(key),
    HWDataFieldType.double_ => HWDouble(key),
    HWDataFieldType.bool_ => HWBool(key),
  };
}
