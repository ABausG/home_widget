import 'package:home_widget_generator/home_widget_generator.dart';

/// Emits Jetpack Glance Composable code from a HWWidget tree.
///
/// [dataExpr] is the Kotlin expression to access data fields.
String emitKotlinWidgetBody(
  HWWidget node, {
  required String dataExpr,
  int indent = 0,
}) {
  return node.toKotlin(indent, dataExpr: dataExpr);
}
