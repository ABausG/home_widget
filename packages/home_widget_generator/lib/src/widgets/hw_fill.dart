part of 'hw_widget.dart';

/// A widget that expands a child of a Row, Column, or Flex
/// so that the child fills the available space.
class HWFill extends HWSingleChildWidget {
  const HWFill({required super.child});

  @override
  Set<String> get kotlinImports => {
        'import androidx.glance.layout.fillMaxSize',
        ...super.kotlinImports,
      };

  static HWFill fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    var childField = obj.getField('child');
    if (childField == null || childField.isNull) {
      childField = obj.getField('(super)')?.getField('child');
    }

    if (childField == null || childField.isNull) {
      throw GeneratorError('HWFill: child parameter is required');
    }

    return HWFill(
      child: decoder.decodeRecursive(childField),
    );
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    // Generate the child
    final childCode = child.toSwift(indent, dataExpr: dataExpr);
    // There are some variations of how Swift modifies modifiers, but typically
    // we just use a helper method to append the frame modifier
    return '$childCode\n${'    ' * indent}.frame(maxWidth: .infinity, maxHeight: .infinity)';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final childCode = child.toKotlin(indent, dataExpr: dataExpr);

    // Uses a local regex helper to securely inject the defaultWeight
    // modifier into the child's top-level compose element.
    return injectGlanceModifier(
        childCode, 'modifier = GlanceModifier.fillMaxSize()');
  }
}
