import '../models/widget_node.dart';
import '../models/widget_spec.dart';

/// Emits SwiftUI view code from a WidgetNode tree.
///
/// [dataExpr] is the Swift expression to access data fields.
/// For the entry view body established in v1.4, this is 'entry.widgetData'.
String emitSwiftWidgetBody(
  WidgetNode node, {
  required String dataExpr,
  int indent = 0,
}) {
  final pad = '    ' * indent; // 4-space indent to match Swift convention
  return switch (node) {
    TextNode(:final content) => '$pad${_emitSwiftText(content, dataExpr)}',
    // v4 will add ColumnNode, RowNode cases
  };
}

String _emitSwiftText(ContentValue content, String dataExpr) {
  return switch (content) {
    StaticValue(:final value) => 'Text("${_escapeSwiftString(value)}")',
    DataRefValue(:final key, :final type) =>
      _emitSwiftDataText(key, type, dataExpr),
  };
}

String _emitSwiftDataText(String key, HWDataFieldType type, String dataExpr) {
  // For String fields: Text(entry.widgetData.countLabel ?? "")
  // For non-String fields: Text(entry.widgetData.count != nil
  //     ? "\(entry.widgetData.count!)" : "0")
  return switch (type) {
    HWDataFieldType.string => 'Text($dataExpr.$key ?? "")',
    HWDataFieldType.int_ =>
      'Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "0")',
    HWDataFieldType.double_ =>
      'Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "0.0")',
    HWDataFieldType.bool_ =>
      'Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "false")',
  };
}

String _escapeSwiftString(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
