import 'package:home_widget_generator/home_widget_generator.dart';

/// Emits Jetpack Glance Composable code from a HWWidget tree.
///
/// [dataExpr] is the Kotlin expression to access data fields.
/// [constraints] is the room the tree renders in, which text in a custom font
/// sizes the bitmap it is drawn into against.
String emitKotlinWidgetBody(
  HWWidget node, {
  required String dataExpr,
  required HWKotlinConstraints constraints,
  int indent = 0,
}) {
  return node.toKotlinIn(indent, dataExpr: dataExpr, constraints: constraints);
}
