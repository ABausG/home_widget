import '../models/widget_node.dart';
import '../models/widget_spec.dart';

/// Emits Jetpack Glance Composable code from a WidgetNode tree.
///
/// [dataExpr] is the Kotlin expression to access data fields.
/// For the Glance widget established in v1.3, this is 'data' (or 'widgetData').
String emitKotlinWidgetBody(
  WidgetNode node, {
  required String dataExpr,
  int indent = 0,
}) {
  final pad = '    ' * indent; // 4-space indent to match Kotlin convention
  return switch (node) {
    TextNode(:final content) => '$pad${_emitKotlinText(content, dataExpr)}',
    // v4 will add ColumnNode, RowNode cases
  };
}

String _emitKotlinText(ContentValue content, String dataExpr) {
  return switch (content) {
    StaticValue(:final value) => 'Text(text = "${_escapeKotlinString(value)}")',
    DataRefValue(:final key, :final type) =>
      _emitKotlinDataText(key, type, dataExpr),
  };
}

String _emitKotlinDataText(String key, HWDataFieldType type, String dataExpr) {
  // For String fields: Text(text = data.countLabel ?: "")
  // For non-String fields: Text(text = (data.count?.toString() ?: "0"))
  return switch (type) {
    HWDataFieldType.string => 'Text(text = $dataExpr.$key ?: "")',
    HWDataFieldType.int_ => 'Text(text = ($dataExpr.$key?.toString() ?: "0"))',
    HWDataFieldType.double_ =>
      'Text(text = ($dataExpr.$key?.toString() ?: "0.0"))',
    HWDataFieldType.bool_ =>
      'Text(text = ($dataExpr.$key?.toString() ?: "false"))',
  };
}

String _escapeKotlinString(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\$', '\\\$');
