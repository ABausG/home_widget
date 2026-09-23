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

  /// Not with a border: its overlay is stroked centred on the edge, so a clip
  /// at the frame would cut off its outer half.
  @override
  bool get swiftClipsFrame =>
      decoration.border == null && child.swiftClipsFrame;

  /// With a border, for the same reason.
  @override
  bool get swiftDrawsPastFrame =>
      decoration.border != null || child.swiftDrawsPastFrame;

  /// None of its own when a border's `Box` wraps the child, which asks for no
  /// room.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) =>
      decoration.border == null
          ? child.kotlinRoomIn(enclosingLinearAxis)
          : const HWKotlinRoom();

  /// Not with a border, which is a `Box` of its own around the child.
  @override
  bool get _kotlinInjectsIntoChild => decoration.border == null;

  @override
  HWDecoratedBox _wrapping(HWWidget widget) =>
      HWDecoratedBox(decoration: decoration, child: widget);

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
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final border = decoration.border;
    final color = decoration.color;

    if (border == null) {
      final childCode =
          child.toKotlin(indent, dataExpr: dataExpr, context: context);
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
