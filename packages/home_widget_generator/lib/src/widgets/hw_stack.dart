part of 'hw_widget.dart';

/// A stack laying its children on top of each other, in the order they are
/// written.
///
/// Mirrors Flutter's `Stack` without positioned children: every child is placed
/// by [alignment], and [fit] decides whether the stack sizes itself from its
/// largest child or takes every pixel it is offered and fills each child out to
/// it. Both platforms clip what a child draws past the stack.
///
/// ```dart
/// HWSizedBox(
///   width: 64,
///   height: 64,
///   child: HWStack(
///     alignment: HWAlignment.bottomEnd,
///     children: [avatar, badge],
///   ),
/// )
/// ```
///
/// Maps to a SwiftUI `ZStack` and a Glance `Box`.
class HWStack extends HWMultiChildWidget {
  /// Where each child sits inside the stack.
  final HWAlignment alignment;

  /// How the stack sizes itself and its children.
  final HWStackFit fit;

  const HWStack({
    this.alignment = HWAlignment.topStart,
    this.fit = HWStackFit.loose,
    required super.children,
  });

  /// [child] as it is emitted, one the platform renders: under
  /// [HWStackFit.expand] filled out to the stack's bounds by an [HWAlign],
  /// which is what Flutter's tight constraints on a non-positioned child come
  /// to here.
  ///
  /// A child filling both axes already emits the same fill and frame, so it is
  /// left as it is. [childWidgets] stays the children as written, so a walker
  /// sees the tree the schema declares.
  HWWidget _placing(HWWidget child) {
    if (fit == HWStackFit.loose) return child;
    final room = child.kotlinRoomIn(null);
    return room.fillsWidth && room.fillsHeight
        ? child
        : HWAlign(alignment: alignment, child: child);
  }

  /// Every pixel offered under [HWStackFit.expand]; loosely, whatever the
  /// widgets the children render ask for.
  ///
  /// Flutter sizes a loose `Stack` to its constraints as soon as a child asks
  /// for them, and a Glance `Box` left to wrap its content can measure to the
  /// content instead, so the stack asks for that room itself. A child picked
  /// where it sits asks for the room of every widget it can land on.
  @override
  HWKotlinRoom kotlinRoomIn(HWAxis? enclosingLinearAxis) {
    if (fit == HWStackFit.expand) {
      return _kotlinFillingRoom(enclosingLinearAxis);
    }

    var fillsWidth = false;
    var fillsHeight = false;
    for (final widget in children.expand(_kotlinLandings)) {
      final room = widget.kotlinRoomIn(null);
      fillsWidth |= room.fillsWidth;
      fillsHeight |= room.fillsHeight;
    }
    return _kotlinFillingRoom(
      enclosingLinearAxis,
      fillsWidth: fillsWidth,
      fillsHeight: fillsHeight,
    );
  }

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// None while the stack renders nothing: the `Box` it would ask for its room
  /// through is not emitted either.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) {
    if (kotlinRendersNothing) return const {};

    final room = kotlinRoomIn(enclosingLinearAxis);
    return {
      'import androidx.glance.layout.Box',
      'import androidx.glance.layout.Alignment',
      if (room.modifiers.isNotEmpty) 'import androidx.glance.GlanceModifier',
      ...room.kotlinImports,
      for (final child in children)
        if (!child.kotlinRendersNothing)
          ..._placing(child).kotlinImportsIn(null),
    };
  }

  /// A frame larger than this stack puts it where it puts its own children.
  @override
  String get swiftFrameAlignment => alignment.swiftAlignment;

  /// Always: a stack clips its own bounds, and a frame around it is the size
  /// Flutter would have laid the stack out at.
  @override
  bool get swiftClipsFrame => true;

  /// A loose stack with nothing to show is zero-sized, the way Flutter sizes
  /// an empty `Stack`; an expanding one still fills what it is offered.
  @override
  bool get swiftRendersNothing =>
      fit == HWStackFit.loose &&
      children.every((child) => child.swiftRendersNothing);

  /// [swiftRendersNothing]'s rule, which also keeps Glance from counting the
  /// stack among the children of the layout around it.
  @override
  bool get kotlinRendersNothing =>
      fit == HWStackFit.loose &&
      children.every((child) => child.kotlinRendersNothing);

  /// Decodes an [HWStack] from an analyzer constant.
  static HWStack fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final alignment = WidgetValueDecoder.decodeEnum(
      WidgetValueDecoder.getField(obj, 'alignment'),
      HWAlignment.values,
    );
    final fit = WidgetValueDecoder.decodeEnum(
      WidgetValueDecoder.getField(obj, 'fit'),
      HWStackFit.values,
    );

    return HWStack(
      alignment: alignment ?? HWAlignment.topStart,
      fit: fit ?? HWStackFit.loose,
      children: _decodeChildren(obj, decoder, 'HWStack'),
    );
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    if (swiftRendersNothing) return '';

    final pad = '    ' * indent;
    final buffer = StringBuffer()
      ..writeln('${pad}ZStack(alignment: ${alignment.swiftAlignment}) {');
    for (final child in children) {
      if (child.swiftRendersNothing) continue;
      buffer.writeln(
        _placing(child)
            .toSwift(indent + 1, dataExpr: dataExpr, context: context),
      );
    }
    buffer.write('$pad}');

    var code = buffer.toString();
    if (fit == HWStackFit.expand) {
      code = applySwiftModifier(
        code,
        '.frame(maxWidth: .infinity, maxHeight: .infinity, '
        'alignment: ${alignment.swiftAlignment})',
        indent,
      );
    }
    return applySwiftModifier(code, '.clipped()', indent);
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    if (kotlinRendersNothing) return '';

    final pad = '    ' * indent;
    final room = kotlinRoomIn(context?.enclosingLinearAxis).modifiers;
    final arguments = [
      if (room.isNotEmpty) 'modifier = GlanceModifier.${room.join('.')}',
      'contentAlignment = ${alignment.kotlinAlignment}',
    ].join(', ');
    final buffer = StringBuffer()..writeln('${pad}Box($arguments) {');
    final childContext = context?.inLinear(null);
    for (final child in children) {
      if (child.kotlinRendersNothing) continue;
      buffer.writeln(
        _placing(child)
            .toKotlin(indent + 1, dataExpr: dataExpr, context: childContext),
      );
    }

    buffer.write('$pad}');
    return buffer.toString();
  }
}

/// Every widget Glance can render where [widget] sits, a choice expanded into
/// each widget it can land on, and one rendering nothing left out.
Iterable<HWWidget> _kotlinLandings(HWWidget widget) sync* {
  final choices = widget._kotlinChoices(null);
  if (choices == null) {
    if (!widget.kotlinRendersNothing) yield widget;
    return;
  }
  for (final choice in choices) {
    yield* _kotlinLandings(choice);
  }
}
