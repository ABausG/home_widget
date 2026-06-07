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

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      'import androidx.glance.layout.Box',
      'import androidx.compose.ui.graphics.Color',
      'import androidx.glance.background',
    };
    if (color is HWThemedColor) {
      imports.add('import androidx.glance.color.ColorProvider');
    }
    return imports.union(super.kotlinImports);
  }

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
  String toSwift(int indent, {required String dataExpr}) {
    final childCode = child.toSwift(indent, dataExpr: dataExpr);
    final modifier =
        '.background(${color.toSwift(indent, dataExpr: dataExpr)})';
    return applySwiftModifier(childCode, modifier, indent);
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final modifier =
        'background(${color.toKotlin(indent, dataExpr: dataExpr)})';

    final childCode = child.toKotlin(indent, dataExpr: dataExpr);
    return injectGlanceModifier(childCode, modifier);
  }
}
