import 'package:home_widget_generator/home_widget_generator.dart';

/// Emits SwiftUI view code from a HWWidget tree.
///
/// [dataExpr] is the Swift expression to access data fields, [context] what the
/// tree needs to know about the platform it is emitted for.
String emitSwiftWidgetBody(
  HWWidget node, {
  required String dataExpr,
  int indent = 0,
  HWEmitContext? context,
}) {
  return node.toSwift(indent, dataExpr: dataExpr, context: context);
}
