part of 'hw_widget.dart';

/// A box decoration with an optional background color and border.
class HWBoxDecoration {
  final HWColor? color;
  final HWBoxBorder? border;

  const HWBoxDecoration({
    this.color,
    this.border,
  });

  Set<String> get kotlinImports => {
        if (color != null) ...color!.kotlinImports,
        if (border != null) ...border!.kotlinImports,
      };

  Set<String> get swiftViewModifiers => {
        if (color != null) ...color!.swiftViewModifiers,
        if (border != null) ...border!.swiftViewModifiers,
      };
}

/// A simple border for [HWBoxDecoration].
///
/// Glance AppWidget does not expose stroke alignment, so borders are emitted as
/// an inside border approximation on Android.
class HWBoxBorder {
  final double radius;
  final double thickness;
  final HWColor color;

  const HWBoxBorder({
    this.radius = 0.0,
    required this.thickness,
    required this.color,
  });

  Set<String> get kotlinImports => color.kotlinImports;

  Set<String> get swiftViewModifiers => color.swiftViewModifiers;
}

/// A widget that decorates its child with a background color and/or border.
///
/// Maps to SwiftUI `.background(...)` / `.overlay(...)` and Glance
/// `GlanceModifier.background(...)` / nested `Box(...)` border approximation.
class HWDecoratedBox extends HWSingleChildWidget {
  final HWBoxDecoration decoration;

  const HWDecoratedBox({
    required super.child,
    required this.decoration,
  });

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      ...super.kotlinImports,
      ...decoration.kotlinImports,
    };

    if (decoration.color != null || decoration.border != null) {
      imports.add('import androidx.glance.background');
      imports.add('import androidx.glance.layout.Box');
    }

    if (decoration.border != null) {
      imports.add('import androidx.compose.ui.unit.dp');
      imports.add('import androidx.glance.appwidget.cornerRadius');
      imports.add('import androidx.glance.layout.padding');
    }

    return imports;
  }

  @override
  Set<String> get swiftViewModifiers => {
        ...super.swiftViewModifiers,
        ...decoration.swiftViewModifiers,
      };

  static HWDecoratedBox fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    final child = childField != null && !childField.isNull
        ? decoder.decodeRecursive(childField)
        : null;

    final decoration = WidgetValueDecoder.decodeBoxDecoration(
      WidgetValueDecoder.getField(obj, 'decoration'),
    );

    if (decoration == null) {
      // coverage:ignore-start
      throw GeneratorError(
        'HWDecoratedBox requires a non-null decoration property',
      );
      // coverage:ignore-end
    }

    return HWDecoratedBox(
      child: child ?? const HWText.fixed(''),
      decoration: decoration,
    );
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    var viewCall = child.toSwift(indent, dataExpr: dataExpr);
    final border = decoration.border;
    final color = decoration.color;

    if (color != null) {
      final String backgroundModifier;
      if (border != null && border.radius > 0) {
        backgroundModifier =
            '.background(RoundedRectangle(cornerRadius: ${border.radius}).fill(${color.toSwift(indent, dataExpr: dataExpr)}))';
      } else {
        backgroundModifier =
            '.background(${color.toSwift(indent, dataExpr: dataExpr)})';
      }
      viewCall = applySwiftModifier(viewCall, backgroundModifier, indent);
    }

    if (border != null) {
      final overlayModifier =
          '.overlay(RoundedRectangle(cornerRadius: ${border.radius}).stroke(${border.color.toSwift(indent, dataExpr: dataExpr)}, lineWidth: ${border.thickness}))';
      viewCall = applySwiftModifier(viewCall, overlayModifier, indent);
    }

    return viewCall;
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final border = decoration.border;
    final color = decoration.color;

    if (border == null) {
      final childCode = child.toKotlin(indent, dataExpr: dataExpr);
      if (color == null) return childCode;

      return injectGlanceModifier(
        childCode,
        'background(${color.toKotlin(indent, dataExpr: dataExpr)})',
      );
    }

    final pad = '    ' * indent;
    final childPad = '    ' * (indent + 1);
    final innerPad = '    ' * (indent + 2);
    final borderColor = border.color.toKotlin(indent, dataExpr: dataExpr);
    final radius = border.radius;
    final innerRadius = (radius - border.thickness).clamp(0.0, radius);

    final outerModifier = [
      'background($borderColor)',
      'cornerRadius($radius.dp)',
      'padding(${border.thickness}.dp)',
    ].join('.');

    final childCode = child.toKotlin(indent + 2, dataExpr: dataExpr);

    if (color == null) {
      return '${pad}Box(\n'
          '${childPad}modifier = GlanceModifier.$outerModifier\n'
          '$pad) {\n'
          '$childCode\n'
          '$pad}';
    }

    final backgroundColor = color.toKotlin(indent, dataExpr: dataExpr);
    return '${pad}Box(\n'
        '${childPad}modifier = GlanceModifier.$outerModifier\n'
        '$pad) {\n'
        '${childPad}Box(\n'
        '${innerPad}modifier = GlanceModifier.background($backgroundColor).cornerRadius($innerRadius.dp)\n'
        '$childPad) {\n'
        '$childCode\n'
        '$childPad}\n'
        '$pad}';
  }
}
