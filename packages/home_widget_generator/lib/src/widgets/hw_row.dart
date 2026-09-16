part of 'hw_widget.dart';

/// A horizontal layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI HStack and Glance Row.
class HWRow extends HWMultiChildWidget {
  final HWCrossAxisAlignment? crossAxisAlignment;
  final HWMainAxisAlignment? mainAxisAlignment;

  const HWRow({
    required super.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });

  /// The alignment this row renders with, always emitted so that neither
  /// platform falls back to its own default.
  HWCrossAxisAlignment get effectiveCrossAxisAlignment =>
      crossAxisAlignment ?? HWCrossAxisAlignment.center;

  /// Whether the main axis is aligned with spacers, which only take room in a
  /// `Row` that fills its width.
  bool get _fillsMainAxis => switch (mainAxisAlignment) {
        HWMainAxisAlignment.center ||
        HWMainAxisAlignment.end ||
        HWMainAxisAlignment.spaceBetween ||
        HWMainAxisAlignment.spaceEvenly =>
          true,
        HWMainAxisAlignment.start || null => false,
      };

  /// Whether a text child has to lose its baseline for the alignment to hold.
  ///
  /// `LinearLayout` corrects a top- or bottom-aligned child by its baseline,
  /// which renders both as baseline alignment; it leaves a centred one alone.
  /// A baseline-aligned row takes the correction off too and places its
  /// children itself: a custom font text is an `Image`, which reports no
  /// baseline for the layout to correct and would stay at the top while its
  /// siblings moved.
  bool get _defeatsBaseline => switch (effectiveCrossAxisAlignment) {
        HWCrossAxisAlignment.start ||
        HWCrossAxisAlignment.end ||
        HWCrossAxisAlignment.baseline =>
          true,
        HWCrossAxisAlignment.center => false,
      };

  /// The ascent of every child this row lines up, by child index, or null when
  /// it lines up nothing itself.
  ///
  /// Only a baseline-aligned row does, and only with two texts to line up: one
  /// text has nothing to be level with, and a child rendering none — an icon, a
  /// picture — has no baseline to go by and stays at the top.
  Map<int, String>? get _kotlinChildAscents {
    if (effectiveCrossAxisAlignment != HWCrossAxisAlignment.baseline) {
      return null;
    }
    final ascents = <int, String>{};
    for (var index = 0; index < children.length; index++) {
      final renderer = children[index].kotlinFirstTextRenderer;
      if (renderer != null) ascents[index] = renderer.kotlinAscentExpression();
    }
    return ascents.length < 2 ? null : ascents;
  }

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      'import androidx.glance.layout.Row',
      'import androidx.glance.layout.Alignment',
    };
    if (mainAxisAlignment != null) {
      imports.add('import androidx.glance.layout.Spacer');
    }
    if (_fillsMainAxis) {
      imports.add('import androidx.glance.layout.fillMaxWidth');
    }
    if (_defeatsBaseline && children.any((c) => c.kotlinReportsBaseline)) {
      imports.add('import androidx.glance.layout.Box');
    }
    if (_kotlinChildAscents != null) {
      imports.addAll({
        'import androidx.compose.ui.unit.dp',
        'import androidx.glance.GlanceModifier',
        'import androidx.glance.layout.Box',
        'import androidx.glance.layout.padding',
        'import es.antonborri.home_widget.HomeWidgetFonts',
      });
    }
    return imports.union(super.kotlinImports);
  }

  static HWRow fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final childrenField = WidgetValueDecoder.getField(obj, 'children');
    final listValue = childrenField?.toListValue();
    if (listValue == null) {
      // coverage:ignore-start
      throw GeneratorError('HWRow: children parameter is required');
      // coverage:ignore-end
    }

    final children = listValue.map(decoder.decodeRecursive).toList();

    final crossAxisAlignmentField = obj.getField('crossAxisAlignment');
    final mainAxisAlignmentField = obj.getField('mainAxisAlignment');

    return HWRow(
      children: children,
      crossAxisAlignment: WidgetValueDecoder.decodeEnum(
        crossAxisAlignmentField,
        HWCrossAxisAlignment.values,
      ),
      mainAxisAlignment: WidgetValueDecoder.decodeEnum(
        mainAxisAlignmentField,
        HWMainAxisAlignment.values,
      ),
    );
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final pad = '    ' * indent;
    final buffer = StringBuffer();

    // `.firstTextBaseline` rather than `.lastTextBaseline`: a TextView reports
    // its first line's baseline, and so does Flutter's CrossAxisAlignment.
    final swiftAlign = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start => '.top',
      HWCrossAxisAlignment.center => '.center',
      HWCrossAxisAlignment.end => '.bottom',
      HWCrossAxisAlignment.baseline => '.firstTextBaseline',
    };

    buffer.writeln('${pad}HStack(alignment: $swiftAlign) {');

    _emitSwiftChildren(buffer, indent + 1, dataExpr, context);

    buffer.write('$pad}');
    return buffer.toString();
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final ascents = _kotlinChildAscents;
    final pad = '    ' * indent;
    // The `val`s live in a `run` of their own so that two rows in one scope
    // cannot collide over them. `run` is inline, so the `Row` inside it is
    // still a composable call.
    final rowIndent = ascents == null ? indent : indent + 1;
    final rowPad = '    ' * rowIndent;
    final buffer = StringBuffer();

    if (ascents != null) {
      buffer.writeln('${pad}run {');
      for (final ascent in ascents.entries) {
        buffer.writeln('${rowPad}val hwAscent${ascent.key} = ${ascent.value}');
      }
      final names = ascents.keys.map((index) => 'hwAscent$index').join(', ');
      buffer.writeln('${rowPad}val hwRowBaseline = listOf($names).max()');
      buffer.writeln(
        '${rowPad}val hwDensity = context.resources.displayMetrics.density',
      );
    }

    final align = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start => 'Alignment.Top',
      HWCrossAxisAlignment.center => 'Alignment.CenterVertically',
      HWCrossAxisAlignment.end => 'Alignment.Bottom',
      HWCrossAxisAlignment.baseline => 'Alignment.Top',
    };

    final arguments = [
      if (_fillsMainAxis) 'modifier = GlanceModifier.fillMaxWidth()',
      'verticalAlignment = $align',
    ].join(', ');
    buffer.writeln('${rowPad}Row($arguments) {');

    // The ascents are keyed by child index, and the spacers an alignment adds
    // are not children; counting the calls is what keeps the two lined up.
    var index = 0;
    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      rowIndent + 1,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) =>
          _emitKotlinChild(child, childIndent, data, context, ascents, index++),
      (pad) => '${pad}Spacer(modifier = GlanceModifier.defaultWeight())',
    );

    buffer.write('$rowPad}');
    if (ascents != null) {
      buffer.write('\n$pad}');
    }
    return buffer.toString();
  }

  /// [child]'s Glance code, wrapped in a `Box` when the row takes its placement
  /// over from the layout.
  ///
  /// A child this row lines up is padded down to the row's baseline; one that
  /// only has to lose a baseline [_defeatsBaseline] would otherwise correct by
  /// gets a bare `Box`, whose `getBaseline()` is -1.
  String _emitKotlinChild(
    HWWidget child,
    int indent,
    String dataExpr,
    HWEmitContext? context,
    Map<int, String>? ascents,
    int index,
  ) {
    final alignsChild = ascents?.containsKey(index) ?? false;
    if (!alignsChild && (!_defeatsBaseline || !child.kotlinReportsBaseline)) {
      return child.toKotlin(indent, dataExpr: dataExpr, context: context);
    }

    final pad = '    ' * indent;
    final inner =
        child.toKotlin(indent + 1, dataExpr: dataExpr, context: context);
    final box = alignsChild
        ? 'Box(modifier = GlanceModifier.padding(top = '
            '((hwRowBaseline - hwAscent$index) / hwDensity).dp)) {'
        : 'Box {';
    return '''
$pad$box
$inner
$pad}''';
  }

  void _emitSwiftChildren(
    StringBuffer buffer,
    int indent,
    String dataExpr,
    HWEmitContext? context,
  ) {
    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) =>
          child.toSwift(childIndent, dataExpr: data, context: context),
      (pad) => '${pad}Spacer()',
    );
  }
}
