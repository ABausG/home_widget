part of 'hw_widget.dart';

/// A widget that paints its area with a specified color, and optionally accepts a child.
///
/// Maps to SwiftUI `.background(...)` and Glance `Box(modifier = GlanceModifier.background(...))`.
class HWColoredBox extends HWSingleChildWidget {
  /// The color the box paints, any color value; while a stored one has no
  /// value the box paints nothing and keeps its layout.
  final HWDataType<int> color;

  const HWColoredBox({
    required super.child,
    required this.color,
  });

  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        ...super.dataDependencies,
        ..._dataDependenciesOf([color]),
      };

  @override
  Iterable<HWDataType<dynamic>> get ownValues => [color];

  /// The background is injected into the child's own composable, so the child
  /// is still what the enclosing layout lays out.
  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.layout.Box',
        'import androidx.compose.ui.graphics.Color',
        'import androidx.glance.background',
        ...hwKotlinColorImports(
          color,
          fallback: HWColorSlotDefault.transparent,
        ),
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

  /// Always, since the color covers the box: SwiftUI frames the child inside
  /// the background, and Glance paints it on the composable the box sizes.
  @override
  HWWidget? _sizedInside(
    double? width,
    double? height, {
    required bool glance,
  }) =>
      _wrapping(
        glance
            ? child._sizedInside(width, height, glance: true) ?? child
            : HWSizedBox(width: width, height: height, child: child),
      );

  @override
  Set<String> get swiftViewModifiers =>
      super.swiftViewModifiers.union(_swiftViewModifiersOf([color]));

  static HWColoredBox fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    final child = childField != null && !childField.isNull
        ? decoder.decodeRecursive(childField)
        : null;

    final color = WidgetValueDecoder.decodeColor(
      obj.getField('color'),
      slot: 'HWColoredBox.color',
    );

    if (color == null) {
      // coverage:ignore-start
      throw GeneratorError('HWColoredBox requires a non-null color property');
      // coverage:ignore-end
    }

    if (child == null) {
      // coverage:ignore-start
      throw GeneratorError('HWColoredBox requires a non-null child property');
      // coverage:ignore-end
    }

    return HWColoredBox(child: child, color: color);
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final childCode =
        child.toSwift(indent, dataExpr: dataExpr, context: context);
    final background = hwSwiftColor(
      color,
      dataExpr: dataExpr,
      fallback: HWColorSlotDefault.transparent,
    );
    return applySwiftModifier(childCode, '.background($background)', indent);
  }

  @override
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final background = hwKotlinColor(
      color,
      dataExpr: dataExpr,
      fallback: HWColorSlotDefault.transparent,
    );
    final modifier = 'background($background)';

    final childCode =
        child.toKotlin(indent, dataExpr: dataExpr, context: context);
    return injectGlanceModifier(childCode, modifier);
  }
}
