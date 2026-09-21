part of 'hw_widget.dart';

/// A widget that paints its area with a specified color, and optionally accepts a child.
///
/// Maps to SwiftUI `.background(...)` and Glance `Box(modifier = GlanceModifier.background(...))`.
class HWColoredBox extends HWSingleChildWidget {
  final HWColor color;

  const HWColoredBox({
    required super.child,
    required this.color,
  });

  /// The background is injected into the child's own composable, so the child
  /// is still what the enclosing layout lays out.
  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.layout.Box',
        'import androidx.compose.ui.graphics.Color',
        'import androidx.glance.background',
        if (color is HWThemedColor)
          'import androidx.glance.color.ColorProvider',
        ...child.kotlinImportsIn(enclosingLinearAxis),
      };

  /// The child's: a text child stays a `Text` with a background.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      child.kotlinBaselineText(context);

  /// Never: the background covers any padding put on the same composable.
  @override
  bool get kotlinPaddingAddsRoom => false;

  @override
  HWColoredBox _wrapping(HWWidget widget) =>
      HWColoredBox(color: color, child: widget);

  @override
  Set<String> get swiftViewModifiers {
    final modifiers = super.swiftViewModifiers;
    return modifiers.union(color.swiftViewModifiers);
  }

  static HWColoredBox fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    final child = childField != null && !childField.isNull
        ? decoder.decodeRecursive(childField)
        : null;

    final color = WidgetValueDecoder.decodeColor(obj.getField('color'));

    if (color == null) {
      // coverage:ignore-start
      throw GeneratorError('HWColoredBox requires a non-null color property');
      // coverage:ignore-end
    }

    return HWColoredBox(
      child:
          child ?? const HWText.fixed(''), // Fallback if no child is provided
      color: color,
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
        '.background(${color.toSwift(indent, dataExpr: dataExpr)})';
    return applySwiftModifier(childCode, modifier, indent);
  }

  @override
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final modifier =
        'background(${color.toKotlin(indent, dataExpr: dataExpr)})';

    final childCode =
        child.toKotlin(indent, dataExpr: dataExpr, context: context);
    return injectGlanceModifier(childCode, modifier);
  }
}
