part of 'hw_widget.dart';

/// A widget that insets its child by the given padding.
///
/// Maps to SwiftUI `.padding(...)` and Glance `GlanceModifier.padding(...)`.
class HWPadding extends HWSingleChildWidget {
  final HWEdgeInsets padding;

  const HWPadding({
    required super.child,
    required this.padding,
  });

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// The padding is injected into the child's own composable, so the child is
  /// still what the enclosing layout lays out.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => {
        ...child.kotlinImportsIn(enclosingLinearAxis),
        'import androidx.compose.ui.unit.dp',
        'import androidx.glance.layout.padding',
        'import androidx.glance.layout.Box',
      };

  /// The child's, unless the padding puts room above it: the row pads from the
  /// top of the box the child sits in, and that room would come along.
  @override
  HWKotlinBaselineText? get kotlinBaselineText =>
      padding.top == 0 ? child.kotlinBaselineText : null;

  static HWPadding fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    final child = childField != null && !childField.isNull
        ? decoder.decodeRecursive(childField)
        : null;

    final padding =
        WidgetValueDecoder.decodeEdgeInsets(obj.getField('padding'));

    if (padding == null) {
      // coverage:ignore-start
      throw GeneratorError('HWPadding requires a non-null padding property');
      // coverage:ignore-end
    }

    return HWPadding(
      child:
          child ?? const HWText.fixed(''), // Fallback if no child is provided
      padding: padding,
    );
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final childCode =
        child.toSwift(indent, dataExpr: dataExpr, context: context);
    final modifier =
        '.padding(EdgeInsets(top: ${padding.top}, leading: ${padding.left}, bottom: ${padding.bottom}, trailing: ${padding.right}))';
    return applySwiftModifier(childCode, modifier, indent);
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final modifier =
        'padding(start = ${padding.left}.dp, top = ${padding.top}.dp, end = ${padding.right}.dp, bottom = ${padding.bottom}.dp)';
    final childCode =
        child.toKotlin(indent, dataExpr: dataExpr, context: context);
    return injectGlanceModifier(childCode, modifier);
  }
}
