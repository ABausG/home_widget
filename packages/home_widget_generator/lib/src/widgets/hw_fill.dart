part of 'hw_widget.dart';

/// A widget that expands a child of a Row, Column, or Flex
/// so that the child fills the available space.
class HWFill extends HWSingleChildWidget {
  static const _swiftModifier =
      '.frame(maxWidth: .infinity, maxHeight: .infinity)';

  const HWFill({required super.child});

  @override
  Set<String> get kotlinImports => {
        'import androidx.glance.layout.fillMaxSize',
        'import androidx.glance.layout.Box',
        ...super.kotlinImports,
      };

  /// Always false: a wrap-content `Box` would take back the room this asks for.
  @override
  bool get kotlinReportsBaseline => false;

  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) =>
      const HWKotlinRoom(fillsWidth: true, fillsHeight: true);

  @override
  HWFill _wrapping(HWWidget widget) => HWFill(child: widget);

  static HWFill fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    if (childField == null || childField.isNull) {
      // coverage:ignore-start
      throw GeneratorError('HWFill: child parameter is required');
      // coverage:ignore-end
    }

    return HWFill(
      child: decoder.decodeRecursive(childField),
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
    return applySwiftModifier(childCode, _swiftModifier, indent);
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    // The room this asks for is the whole box, so a child asking for its own
    // main axis has no siblings left to starve.
    final childCode = child.toKotlin(
      indent,
      dataExpr: dataExpr,
      context: context?.inLinear(null),
    );

    // Uses a local regex helper to securely inject the fillMaxSize
    // modifier into the child's top-level Glance composable.
    return injectGlanceModifier(childCode, 'fillMaxSize()');
  }
}
