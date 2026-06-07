import 'package:home_widget_generator/home_widget_generator.dart';

/// Emits SwiftUI view code from a HWWidget tree.
///
/// [dataExpr] is the Swift expression to access data fields.
String emitSwiftWidgetBody(
  HWWidget node, {
  required String dataExpr,
  int indent = 0,
}) {
  return node.toSwift(indent, dataExpr: dataExpr);
}
