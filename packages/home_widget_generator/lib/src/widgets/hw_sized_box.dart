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

  /// The child's: a frame around this box is the room the child is sized to,
  /// and a gap has nothing to clip.
  @override
  bool get swiftClipsFrame => child?.swiftClipsFrame ?? false;

  /// The child's, as [swiftClipsFrame].
  @override
  bool get swiftDrawsPastFrame => child?.swiftDrawsPastFrame ?? false;

  /// Nothing while this box renders nothing: neither the `Spacer` a gap asking
  /// for no room would be nor the modifiers around a child rendering nothing
  /// are emitted.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) {
    if (kotlinRendersNothing) return const {};

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

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// Whether both axes resolve to no room at all, which is what a box without
  /// a child to size itself from renders as.
  bool get _isEmptyGap => (width ?? 0) == 0 && (height ?? 0) == 0;

  /// Whether an axis is sized to a number of pixels, rather than filled or
  /// left to the child.
  bool get _hasFiniteSize =>
      (width?.isFinite ?? false) || (height?.isFinite ?? false);

  /// A gap asking for no room, or a box around a child rendering nothing: a
  /// frame around nothing is nothing.
  @override
  bool get swiftRendersNothing => child?.swiftRendersNothing ?? _isEmptyGap;

  /// [swiftRendersNothing]'s rule, which also keeps Glance from counting a
  /// `Spacer` of no size among the children of a stack.
  @override
  bool get kotlinRendersNothing => child?.kotlinRendersNothing ?? _isEmptyGap;

  /// The room the outermost composable asks for: a weight along the main axis
  /// of the stack around it, a fill on the other one.
  ///
  /// A finite size is no room — it is injected into the child, which the
  /// wrap-content `Box` a stack may put around it then sits tight around. An
  /// axis left open is the child's to size, so the room the child asks for
  /// there is this box's too; the child is only told about the enclosing axis
  /// while it is open, so a weight it asks for is always along an open axis.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) {
    final own = _kotlinFillingRoom(
      enclosingLinearAxis,
      fillsWidth: width == double.infinity,
      fillsHeight: height == double.infinity,
    );
    final child = this.child;
    if (child == null) return own;

    final asked = child.kotlinRoomIn(_childAxis(enclosingLinearAxis));
    return HWKotlinRoom(
      weight: own.weight || asked.weight,
      fillsWidth: own.fillsWidth || (width == null && asked.fillsWidth),
      fillsHeight: own.fillsHeight || (height == null && asked.fillsHeight),
    );
  }

  /// False once an axis is sized: Glance takes the padding out of the pixels
  /// the size asks for, so a gap would eat the content instead of sitting
  /// outside it.
  @override
  bool get kotlinPaddingAddsRoom =>
      _hasFiniteSize ? false : child?.kotlinPaddingAddsRoom ?? true;

  /// [widget] as this box's modifiers land on it: sized, unless it renders
  /// nothing for them to go on.
  HWWidget _kotlinWrapping(HWWidget widget) => widget.kotlinRendersNothing
      ? widget
      : HWSizedBox(width: width, height: height, child: widget);

  /// The size is injected into whichever widget the child's Glance output is
  /// picked from, so the box sits on each of them.
  @override
  List<HWWidget>? _kotlinChoices(HWEmitContext? context) =>
      child?._kotlinChoices(context)?.map(_kotlinWrapping).toList();

  @override
  String? _kotlinChoice(
    int indent, {
    required String dataExpr,
    required HWEmitContext? context,
    required String Function(HWWidget widget, int indent) emit,
  }) =>
      child?._kotlinChoice(
        indent,
        dataExpr: dataExpr,
        context: context,
        emit: (widget, indent) => emit(_kotlinWrapping(widget), indent),
      );

  @override
  Set<String> get _kotlinChoiceImports =>
      child?._kotlinChoiceImports ?? const {};

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
    if (swiftRendersNothing) return '';

    final child = this.child;
    var code = child == null
        ? '${'    ' * indent}Color.clear'
        : child.toSwift(indent, dataExpr: dataExpr, context: context);

    for (final modifier in _swiftModifiers(isGap: child == null)) {
      code = applySwiftModifier(code, modifier, indent);
    }

    // SwiftUI draws a child past the frame it was given, so an axis sized to
    // zero, and a child Flutter would have sized to the box, only hold once
    // the overflow is cut off.
    if (child != null &&
        (width == 0 ||
            height == 0 ||
            (child.swiftClipsFrame && _hasFiniteSize))) {
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
    if (kotlinRendersNothing) return '';

    final modifiers = _kotlinModifiers(context?.enclosingLinearAxis);
    final child = this.child;

    if (child == null) {
      final pad = '    ' * indent;
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
