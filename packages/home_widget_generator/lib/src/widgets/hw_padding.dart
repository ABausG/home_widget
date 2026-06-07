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
        'import androidx.glance.layout.Box',
      };

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
  String toSwift(int indent, {required String dataExpr}) {
    final childCode = child.toSwift(indent, dataExpr: dataExpr);
    final modifier =
        '.padding(EdgeInsets(top: ${padding.top}, leading: ${padding.left}, bottom: ${padding.bottom}, trailing: ${padding.right}))';
    return applySwiftModifier(childCode, modifier, indent);
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final modifier =
        'padding(start = ${padding.left}.dp, top = ${padding.top}.dp, end = ${padding.right}.dp, bottom = ${padding.bottom}.dp)';
    final childCode = child.toKotlin(indent, dataExpr: dataExpr);
    return injectGlanceModifier(childCode, modifier);
  }
}
