part of 'hw_widget.dart';

/// A box with a fixed width and/or height, optionally around a child.
///
/// Mirrors Flutter's `SizedBox`: an axis given a size is imposed on the child,
/// an axis left null is sized by the child, and `double.infinity` takes every
/// pixel the enclosing layout offers. Without a child the box is a gap, and an
/// axis left null collapses to zero.
///
/// ```dart
/// HWSizedBox(width: 8)                       // a gap in a row
/// HWSizedBox(width: 80, height: 40, child: …) // a bounded child
/// HWSizedBox.expand(child: …)                 // fills the widget
/// ```
///
/// Maps to SwiftUI `.frame(...)` and Glance `GlanceModifier.width/height(...)`.
class HWSizedBox extends HWWidget {
  /// Width in logical pixels, `double.infinity` for every pixel offered, or
  /// null to size from the child.
  final double? width;

  /// Height in logical pixels, `double.infinity` for every pixel offered, or
  /// null to size from the child.
  final double? height;

  /// The widget this box sizes, or null for a gap.
  final HWWidget? child;

  const HWSizedBox({this.width, this.height, this.child});

  /// A box as small as it can be on both axes.
  const HWSizedBox.shrink({this.child})
      : width = 0,
        height = 0;

  /// A box taking every pixel offered on both axes.
  const HWSizedBox.expand({this.child})
      : width = double.infinity,
        height = double.infinity;

  @override
  List<HWWidget> get childWidgets => [if (child case final child?) child];

  @override
  Set<HWDataType<dynamic>> get dataDependencies =>
      child?.dataDependencies ?? const {};

  @override
  Set<String> get swiftViewModifiers => child?.swiftViewModifiers ?? const {};

  @override
  String get swiftFrameAlignment => child?.swiftFrameAlignment ?? '.topLeading';

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) {
    final modifiers = _kotlinModifiers(enclosingLinearAxis);
    final child = this.child;
    return {
      if (modifiers.isNotEmpty) 'import androidx.glance.GlanceModifier',
      for (final modifier in modifiers) ..._kotlinModifierImports(modifier),
      if (child == null)
        'import androidx.glance.layout.Spacer'
      else ...{
        if (modifiers.isNotEmpty) 'import androidx.glance.layout.Box',
        ...child.kotlinImportsIn(_childAxis(enclosingLinearAxis)),
      },
    };
  }

  /// The child's, unless this box sets the height: the row pads the child from
  /// the top of the box it sits in, and a height moves that top off the glyphs.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      height == null ? child?.kotlinBaselineText(context) : null;

  /// The child's, unless an axis is infinite: the wrap-content `Box` a row
  /// would put around it takes back the room that axis asks for.
  @override
  bool get kotlinReportsBaseline =>
      width != double.infinity &&
      height != double.infinity &&
      (child?.kotlinReportsBaseline ?? false);

  /// Decodes an [HWSizedBox] from an analyzer constant.
  static HWSizedBox fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    final child = childField != null && !childField.isNull
        ? decoder.decodeRecursive(childField)
        : null;

    return HWSizedBox(
      width: _decodeDimension(obj, 'width'),
      height: _decodeDimension(obj, 'height'),
      child: child,
    );
  }

  /// A dimension written as an `int` literal, a `double` literal or
  /// `double.infinity`, or null when the axis is left open.
  static double? _decodeDimension(DartObject obj, String name) {
    final field = WidgetValueDecoder.getField(obj, name);
    if (field == null || field.isNull) return null;

    final value = field.toDoubleValue() ?? field.toIntValue()?.toDouble();
    if (value == null) {
      // coverage:ignore-start
      throw GeneratorError(
        'HWSizedBox: $name has to be a constant number or double.infinity.',
      );
      // coverage:ignore-end
    }
    if (value.isNaN || value < 0) {
      throw GeneratorError(
        'HWSizedBox: $name has to be zero or more, got $value.',
      );
    }
    return value;
  }

  /// The axis the child is told about, which is the enclosing one only while
  /// this box leaves it to the child.
  HWAxis? _childAxis(HWAxis? enclosingLinearAxis) =>
      switch (enclosingLinearAxis) {
        HWAxis.horizontal when width != null => null,
        HWAxis.vertical when height != null => null,
        final axis => axis,
      };

  /// The Glance modifiers sizing this box inside a layout running along
  /// [enclosingLinearAxis].
  ///
  /// A Glance `Row` or `Column` is a `LinearLayout`, so a child asking to fill
  /// its main axis takes every pixel and leaves its siblings none; along that
  /// axis the box asks for the same room by weight instead.
  List<String> _kotlinModifiers(HWAxis? enclosingLinearAxis) {
    final width = this.width;
    final height = this.height;
    if (width == double.infinity &&
        height == double.infinity &&
        enclosingLinearAxis == null) {
      return const ['fillMaxSize()'];
    }
    return [
      if (width != null)
        if (width == double.infinity)
          enclosingLinearAxis == HWAxis.horizontal
              ? 'defaultWeight()'
              : 'fillMaxWidth()'
        else
          'width($width.dp)',
      if (height != null)
        if (height == double.infinity)
          enclosingLinearAxis == HWAxis.vertical
              ? 'defaultWeight()'
              : 'fillMaxHeight()'
        else
          'height($height.dp)',
    ];
  }

  /// The imports one entry of [_kotlinModifiers] needs; `defaultWeight` is a
  /// member of the `Row` / `Column` scope and needs none.
  static Set<String> _kotlinModifierImports(String modifier) {
    final name = modifier.substring(0, modifier.indexOf('('));
    return {
      if (name != 'defaultWeight') 'import androidx.glance.layout.$name',
      if (modifier.endsWith('.dp)')) 'import androidx.compose.ui.unit.dp',
    };
  }

  /// The SwiftUI `.frame` modifiers sizing this box.
  ///
  /// `frame(width:height:alignment:)` and `frame(maxWidth:maxHeight:...)` are
  /// different overloads, so a box with one fixed and one infinite axis chains
  /// both. A child smaller than the box is placed by its own
  /// [HWWidget.swiftFrameAlignment], the way Flutter and Glance place it.
  List<String> _swiftModifiers({required bool isGap}) {
    // A gap has no child to size it, so an axis left open collapses to zero,
    // the way Flutter's SizedBox does.
    final child = this.child;
    final width = isGap ? this.width ?? 0.0 : this.width;
    final height = isGap ? this.height ?? 0.0 : this.height;

    final fixed = <String>[
      if (width != null && width.isFinite) 'width: $width',
      if (height != null && height.isFinite) 'height: $height',
    ];
    final flexible = <String>[
      if (width == double.infinity) 'maxWidth: .infinity',
      if (height == double.infinity) 'maxHeight: .infinity',
    ];
    final alignment =
        child == null ? '' : ', alignment: ${child.swiftFrameAlignment}';

    return [
      if (fixed.isNotEmpty) '.frame(${fixed.join(', ')}$alignment)',
      if (flexible.isNotEmpty) '.frame(${flexible.join(', ')}$alignment)',
    ];
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final child = this.child;

    // A zero-size view still takes the spacing a stack puts around it, so a gap
    // asking for no room at all has to be no view.
    if (child == null && (width ?? 0) == 0 && (height ?? 0) == 0) {
      return '${'    ' * indent}EmptyView()';
    }

    var code = child == null
        ? '${'    ' * indent}Color.clear'
        : child.toSwift(indent, dataExpr: dataExpr, context: context);

    for (final modifier in _swiftModifiers(isGap: child == null)) {
      code = applySwiftModifier(code, modifier, indent);
    }

    // SwiftUI draws a child past the frame it was given, so an axis sized to
    // zero only hides it once the overflow is cut off.
    if (child != null && (width == 0 || height == 0)) {
      code = applySwiftModifier(code, '.clipped()', indent);
    }
    return code;
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final modifiers = _kotlinModifiers(context?.enclosingLinearAxis);
    final child = this.child;

    if (child == null) {
      final pad = '    ' * indent;
      if (modifiers.isEmpty) return '${pad}Spacer()';
      return '${pad}Spacer(modifier = GlanceModifier.${modifiers.join('.')})';
    }

    final childCode = child.toKotlin(
      indent,
      dataExpr: dataExpr,
      context: context?.inLinear(_childAxis(context.enclosingLinearAxis)),
    );
    if (modifiers.isEmpty) return childCode;

    return injectGlanceModifier(
      childCode,
      modifiers.join('.'),
      weightAxis: switch (context?.enclosingLinearAxis) {
        HWAxis.horizontal => GlanceSizeAxis.width,
        HWAxis.vertical => GlanceSizeAxis.height,
        null => null,
      },
    );
  }
}
