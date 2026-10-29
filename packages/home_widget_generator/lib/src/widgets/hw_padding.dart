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

  /// Whether the padding goes on a `Box` of its own around the child.
  ///
  /// Glance pads a view inside its own bounds, so a decoration the child's
  /// composable paints — the one a size put around it would reach — would
  /// cover the padding it was given; Flutter leaves the gap around a
  /// decoration empty.
  bool get _kotlinBoxes =>
      !child.kotlinPaddingAddsRoom &&
      child._sizedInside(null, null, glance: true) != null;

  /// The padding is injected into the child's own composable, so the child is
  /// still what the enclosing layout lays out, unless it goes on a `Box`.
  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) => {
        ...child.kotlinImportsIn(_kotlinBoxes ? null : enclosingLinearAxis),
        'import androidx.compose.ui.unit.dp',
        'import androidx.glance.layout.padding',
        'import androidx.glance.layout.Box',
        if (_kotlinBoxes) ...{
          'import androidx.glance.GlanceModifier',
          ...kotlinRoomIn(enclosingLinearAxis).kotlinImports,
        },
      };

  /// The child's, unless the padding puts room above it: the row pads from the
  /// top of the box the child sits in, and that room would come along.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      padding.top == 0 && !_kotlinBoxes
          ? child.kotlinBaselineText(context)
          : null;

  /// Not through a `Box` of its own, which has no baseline.
  @override
  bool get kotlinReportsBaseline =>
      !_kotlinBoxes && child.kotlinReportsBaseline;

  /// Always through a `Box` of its own, which paints nothing.
  @override
  bool get kotlinPaddingAddsRoom => _kotlinBoxes || child.kotlinPaddingAddsRoom;

  /// Through a `Box` of its own, the room the child fills inside it.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) => _kotlinBoxes
      ? _kotlinBoxRoom(child, enclosingLinearAxis)
      : child.kotlinRoomIn(enclosingLinearAxis);

  @override
  bool get _kotlinInjectsIntoChild => !_kotlinBoxes;

  @override
  HWPadding _wrapping(HWWidget widget) =>
      HWPadding(padding: padding, child: widget);

  /// While the child takes the size, less the insets on a finite axis: a
  /// Flutter padding hands its child what is left. On Glance only the child
  /// of the padding's own `Box` is sized, to fill it.
  @override
  HWWidget? _sizedInside(
    double? width,
    double? height, {
    required bool glance,
  }) {
    final innerWidth = _inset(width, padding.left + padding.right);
    final innerHeight = _inset(height, padding.top + padding.bottom);
    final inner = child._sizedInside(innerWidth, innerHeight, glance: glance);
    if (inner == null) return null;
    if (glance && !_kotlinBoxes) return _wrapping(inner);
    return _wrapping(
      HWSizedBox(width: innerWidth, height: innerHeight, child: child),
    );
  }

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
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final modifier =
        'padding(start = ${padding.left}.dp, top = ${padding.top}.dp, end = ${padding.right}.dp, bottom = ${padding.bottom}.dp)';
    if (!_kotlinBoxes) {
      final childCode =
          child.toKotlin(indent, dataExpr: dataExpr, context: context);
      return injectGlanceModifier(childCode, modifier);
    }

    final pad = '    ' * indent;
    final modifiers = [
      ...kotlinRoomIn(context?.enclosingLinearAxis).modifiers,
      modifier,
    ].join('.');
    final childCode = child.toKotlin(
      indent + 1,
      dataExpr: dataExpr,
      context: context?.inLinear(null),
    );
    return '''
${pad}Box(modifier = GlanceModifier.$modifiers) {
$childCode
$pad}''';
  }
}
