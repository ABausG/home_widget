part of 'hw_widget.dart';

/// A widget that takes every pixel it is offered and places its child in it.
///
/// Mirrors Flutter's `Align` without the width and height factors: it fills
/// both axes of whatever lays it out, then puts the child at [alignment].
/// Works at the root of a widget and anywhere inside it.
///
/// ```dart
/// HWAlign(alignment: HWAlignment.bottomEnd, child: HWText.fixed('3'))
/// ```
///
/// Maps to a SwiftUI `.frame(maxWidth:maxHeight:alignment:)` and a Glance `Box`
/// with a `contentAlignment`.
class HWAlign extends HWSingleChildWidget {
  /// Where the child sits inside the room this widget takes.
  final HWAlignment alignment;

  const HWAlign({
    this.alignment = HWAlignment.center,
    required super.child,
  });

  /// A `Box` of its own, so the child is no longer what the enclosing layout
  /// lays out.
  @override
  bool get _kotlinInjectsIntoChild => false;

  /// The whole of both axes, which is what the `Box` asks for.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) =>
      _kotlinFillingRoom(enclosingLinearAxis);

  /// Never: like Flutter's `Align` around an empty child, this widget still
  /// takes all the room it is offered.
  @override
  bool get swiftRendersNothing => false;

  /// Never, as [swiftRendersNothing].
  @override
  bool get kotlinRendersNothing => false;

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) =>
      _kotlinImportsAroundChild(enclosingLinearAxis);

  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.GlanceModifier',
        'import androidx.glance.layout.Box',
        'import androidx.glance.layout.Alignment',
        ...kotlinRoomIn(enclosingLinearAxis).kotlinImports,
        if (!child.kotlinRendersNothing) ...child.kotlinImportsIn(null),
      };

  /// Never: the emitted `Box` has no baseline of its own.
  @override
  bool get kotlinReportsBaseline => false;

  /// Always: a filling `Box` takes the gap inside its bounds and places the
  /// child in what is left, which looks the same as room outside it.
  @override
  bool get kotlinPaddingAddsRoom => true;

  /// Its own: a frame larger than this widget is where the child ends up, and
  /// this widget puts it at [alignment].
  @override
  String get swiftFrameAlignment => alignment.swiftAlignment;

  // coverage:ignore-start
  /// Never asked for: a `Box` of its own carries no modifier down into the
  /// widgets a choice is picked from.
  @override
  HWAlign _wrapping(HWWidget widget) =>
      HWAlign(alignment: alignment, child: widget);
  // coverage:ignore-end

  /// Decodes an [HWAlign] from an analyzer constant.
  static HWAlign fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final childField = WidgetValueDecoder.getField(obj, 'child');
    if (childField == null || childField.isNull) {
      // coverage:ignore-start
      throw GeneratorError('HWAlign requires a child');
      // coverage:ignore-end
    }

    final alignment = WidgetValueDecoder.decodeEnum(
      WidgetValueDecoder.getField(obj, 'alignment'),
      HWAlignment.values,
    );

    return HWAlign(
      alignment: alignment ?? HWAlignment.center,
      child: decoder.decodeRecursive(childField),
    );
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final code = child.swiftRendersNothing
        ? '${'    ' * indent}Color.clear'
        : child.toSwift(indent, dataExpr: dataExpr, context: context);
    return applySwiftModifier(
      code,
      '.frame(maxWidth: .infinity, maxHeight: .infinity, '
      'alignment: ${alignment.swiftAlignment})',
      indent,
    );
  }

  /// The `Box` around the child, an empty one around a child rendering
  /// nothing.
  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) =>
      _kotlinAroundChild(indent, dataExpr: dataExpr, context: context);

  @override
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent;
    final room = kotlinRoomIn(context?.enclosingLinearAxis).modifiers.join('.');
    final arguments = [
      'modifier = GlanceModifier.$room',
      'contentAlignment = ${alignment.kotlinAlignment}',
    ].join(', ');
    final open = '${pad}Box($arguments) {';
    if (child.kotlinRendersNothing) return '$open}';

    final childCode = child.toKotlin(
      indent + 1,
      dataExpr: dataExpr,
      context: context?.inLinear(null),
    );
    return '''
$open
$childCode
$pad}''';
  }
}
