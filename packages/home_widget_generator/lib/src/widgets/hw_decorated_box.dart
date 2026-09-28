part of 'hw_widget.dart';

/// A box decoration with an optional background color, border and corner
/// radius.
class HWBoxDecoration {
  final HWColor? color;
  final HWBoxBorder? border;

  /// The rounding of the corners of both the background and the border, or
  /// null for square corners.
  final HWBorderRadius? borderRadius;

  const HWBoxDecoration({
    this.color,
    this.border,
    this.borderRadius,
  });

  /// The corner radius in logical pixels, 0 for square corners.
  double get _radius => borderRadius?.radius ?? 0.0;

  Set<String> get kotlinImports => {
        if (color != null) ...color!.kotlinImports,
        if (border != null) ...border!.kotlinImports,
      };

  Set<String> get swiftViewModifiers => {
        if (color != null) ...color!.swiftViewModifiers,
        if (border != null) ...border!.swiftViewModifiers,
      };
}

/// The rounding of the corners of an [HWBoxDecoration].
///
/// Every corner shares one radius: Glance rounds a view with a single
/// `cornerRadius`.
class HWBorderRadius {
  /// The radius of every corner, in logical pixels.
  final double radius;

  /// Rounds every corner with a circle of [radius].
  const HWBorderRadius.circular(this.radius);
}

/// A simple border for [HWBoxDecoration], drawn inside the box like Flutter's
/// default `BorderSide.strokeAlignInside`.
///
/// SwiftUI strokes it with `strokeBorder`; Glance has no stroke, so Android
/// insets a fill by [thickness] inside a `Box` of the border color.
class HWBoxBorder {
  final double thickness;
  final HWColor color;

  const HWBoxBorder({
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

  /// Without a border the decoration is injected into the child's own
  /// composable, so the child is still what the enclosing layout lays out; a
  /// border puts a `Box` of its own in between.
  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) {
    final imports = <String>{
      ...child.kotlinImportsIn(
        decoration.border == null ? enclosingLinearAxis : null,
      ),
      ...decoration.kotlinImports,
    };

    if (decoration.color != null || decoration.border != null) {
      imports.add('import androidx.glance.background');
      imports.add('import androidx.glance.layout.Box');
    }

    if (decoration.border != null ||
        (decoration.color != null && decoration._radius > 0)) {
      imports.add('import androidx.compose.ui.unit.dp');
      imports.add('import androidx.glance.appwidget.cornerRadius');
    }

    if (decoration.border != null) {
      imports.add('import androidx.glance.layout.padding');
      imports.addAll(kotlinRoomIn(enclosingLinearAxis).kotlinImports);
      if (decoration.color != null) {
        imports.addAll(_kotlinFillRoom.kotlinImports);
      }
    }

    return imports;
  }

  /// The axes a border's `Box` fills inside whatever lays it out, which are
  /// the ones the child fills inside it.
  HWKotlinRoom get _kotlinFillRoom => _kotlinBoxRoom(child, null);

  @override
  Set<String> get swiftViewModifiers => {
        ...super.swiftViewModifiers,
        ...decoration.swiftViewModifiers,
      };

  /// A border is drawn as a surrounding `Box`, which has no baseline; without
  /// one the decoration is injected into the child's own composable.
  @override
  bool get kotlinReportsBaseline =>
      decoration.border == null && child.kotlinReportsBaseline;

  /// The child's, unless a border puts a `Box` around it: the row pads from the
  /// top of the box the child sits in, and the border would come along.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      decoration.border == null ? child.kotlinBaselineText(context) : null;

  /// Not with a color or a border, either of which covers any padding put on
  /// the same composable.
  @override
  bool get kotlinPaddingAddsRoom =>
      decoration.color == null &&
      decoration.border == null &&
      child.kotlinPaddingAddsRoom;

  /// With a border, the room the child fills inside the border's `Box`, which
  /// the `Box` asks for in turn.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) {
    return decoration.border == null
        ? child.kotlinRoomIn(enclosingLinearAxis)
        : _kotlinBoxRoom(child, enclosingLinearAxis);
  }

  /// Not with a border, which is a `Box` of its own around the child.
  @override
  bool get _kotlinInjectsIntoChild => decoration.border == null;

  @override
  HWDecoratedBox _wrapping(HWWidget widget) =>
      HWDecoratedBox(decoration: decoration, child: widget);

  /// Whenever the decoration paints, or passes the size on to one that does.
  /// On Glance a border's `Box` is sized by the box around it, and the child
  /// fills it; without a border the decoration is on the sized composable.
  @override
  HWWidget? _sizedInside(
    double? width,
    double? height, {
    required bool glance,
  }) {
    final inner = child._sizedInside(width, height, glance: glance);
    final paints = decoration.color != null || decoration.border != null;
    if (!paints && inner == null) return null;
    if (glance && decoration.border == null) return _wrapping(inner ?? child);
    return _wrapping(HWSizedBox(width: width, height: height, child: child));
  }

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
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    var viewCall = child.toSwift(indent, dataExpr: dataExpr, context: context);
    final border = decoration.border;
    final color = decoration.color;
    final radius = decoration._radius;

    if (color != null) {
      final String backgroundModifier;
      if (radius > 0) {
        backgroundModifier =
            '.background(RoundedRectangle(cornerRadius: $radius).fill(${color.toSwift(indent, dataExpr: dataExpr)}))';
      } else {
        backgroundModifier =
            '.background(${color.toSwift(indent, dataExpr: dataExpr)})';
      }
      viewCall = applySwiftModifier(viewCall, backgroundModifier, indent);
    }

    if (border != null) {
      final overlayModifier =
          '.overlay(RoundedRectangle(cornerRadius: $radius).strokeBorder(${border.color.toSwift(indent, dataExpr: dataExpr)}, lineWidth: ${border.thickness}))';
      viewCall = applySwiftModifier(viewCall, overlayModifier, indent);
    }

    return viewCall;
  }

  @override
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final border = decoration.border;
    final color = decoration.color;
    final radius = decoration._radius;

    if (border == null) {
      final childCode =
          child.toKotlin(indent, dataExpr: dataExpr, context: context);
      if (color == null) return childCode;

      return injectGlanceModifier(
        childCode,
        [
          'background(${color.toKotlin(indent, dataExpr: dataExpr)})',
          if (radius > 0) 'cornerRadius($radius.dp)',
        ].join('.'),
      );
    }

    final pad = '    ' * indent;
    final childPad = '    ' * (indent + 1);
    final innerPad = '    ' * (indent + 2);
    final borderColor = border.color.toKotlin(indent, dataExpr: dataExpr);
    final innerRadius = (radius - border.thickness).clamp(0.0, radius);

    final outerModifier = [
      ...kotlinRoomIn(context?.enclosingLinearAxis).modifiers,
      'background($borderColor)',
      'cornerRadius($radius.dp)',
      'padding(${border.thickness}.dp)',
    ].join('.');

    // The border's `Box` is what the enclosing layout lays out now.
    final childCode = child.toKotlin(
      indent + 2,
      dataExpr: dataExpr,
      context: context?.inLinear(null),
    );

    if (color == null) {
      return '${pad}Box(\n'
          '${childPad}modifier = GlanceModifier.$outerModifier\n'
          '$pad) {\n'
          '$childCode\n'
          '$pad}';
    }

    final backgroundColor = color.toKotlin(indent, dataExpr: dataExpr);
    final innerModifier = [
      ..._kotlinFillRoom.modifiers,
      'background($backgroundColor)',
      'cornerRadius($innerRadius.dp)',
    ].join('.');
    return '${pad}Box(\n'
        '${childPad}modifier = GlanceModifier.$outerModifier\n'
        '$pad) {\n'
        '${childPad}Box(\n'
        '${innerPad}modifier = GlanceModifier.$innerModifier\n'
        '$childPad) {\n'
        '$childCode\n'
        '$childPad}\n'
        '$pad}';
  }
}
