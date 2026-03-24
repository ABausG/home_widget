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
  Set<String> get kotlinImports => {
        ...super.kotlinImports,
        'import androidx.compose.ui.unit.dp',
        'import androidx.glance.layout.padding',
      };

  static HWPadding fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    var childField = obj.getField('child');
    if (childField == null || childField.isNull) {
      childField = obj.getField('(super)')?.getField('child');
    }

    final child = childField != null && !childField.isNull
        ? decoder.decodeRecursive(childField)
        : null;

    final padding =
        WidgetValueDecoder.decodeEdgeInsets(obj.getField('padding'));

    if (padding == null) {
      throw GeneratorError('HWPadding requires a non-null padding property');
    }

    return HWPadding(
      child:
          child ?? const HWText.fixed(''), // Fallback if no child is provided
      padding: padding,
    );
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent;
    final childCode = child.toSwift(indent, dataExpr: dataExpr);

    return '$childCode\n$pad.padding(EdgeInsets(top: ${padding.top}, leading: ${padding.left}, bottom: ${padding.bottom}, trailing: ${padding.right}))';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final modifier =
        'padding(start = ${padding.left}.dp, top = ${padding.top}.dp, end = ${padding.right}.dp, bottom = ${padding.bottom}.dp)';
    final childCode = child.toKotlin(indent, dataExpr: dataExpr);
    return injectGlanceModifier(childCode, modifier);
  }
}
