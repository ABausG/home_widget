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
  String toSwift(int indent, {required String dataExpr}) {
    final childCode = child.toSwift(indent, dataExpr: dataExpr);
    return applySwiftModifier(childCode, _swiftModifier, indent);
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final childCode = child.toKotlin(indent, dataExpr: dataExpr);

    // Uses a local regex helper to securely inject the fillMaxSize
    // modifier into the child's top-level Glance composable.
    return injectGlanceModifier(childCode, 'fillMaxSize()');
  }
}
