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

  /// Whether a text child has to lose its baseline for the alignment to hold.
  ///
  /// `LinearLayout` corrects a top- or bottom-aligned child by its baseline,
  /// which renders both as baseline alignment; it leaves a centred one alone.
  bool get _defeatsBaseline => switch (effectiveCrossAxisAlignment) {
        HWCrossAxisAlignment.start || HWCrossAxisAlignment.end => true,
        HWCrossAxisAlignment.center || HWCrossAxisAlignment.baseline => false,
      };

  /// The text of every child this row places itself, by child index, or null
  /// when the layout already lines the children up.
  ///
  /// A Glance `Row` is a `LinearLayout` with `baselineAligned` on, so an
  /// `Alignment.Top` row of Glance `Text`s is baseline-aligned by the framework
  /// already. Only a bitmap text needs placing: it is an `Image`, reports no
  /// baseline, and would stay at the top while its siblings moved. Two texts
  /// are the least there is to line up, and a child rendering none — an icon, a
  /// picture — stays at the top either way.
  Map<int, HWKotlinBaselineText>? _kotlinBaselineChildren(
    HWEmitContext? context,
  ) {
    if (effectiveCrossAxisAlignment != HWCrossAxisAlignment.baseline) {
      return null;
    }
    final texts = <int, HWKotlinBaselineText>{};
    for (var index = 0; index < children.length; index++) {
      if (children[index].kotlinBaselineText(context) case final text?) {
        texts[index] = text;
      }
    }
    if (texts.length < 2) return null;
    if (!texts.values.any((text) => text.isBitmap)) return null;
    return texts;
  }

  /// Whether the child at [index] is emitted inside a `Box` of the row's own,
  /// which is what lays it out then.
  bool _wrapsChild(int index, Map<int, HWKotlinBaselineText>? texts) =>
      (texts?.containsKey(index) ?? false) ||
      (_defeatsBaseline && children[index].kotlinReportsBaseline);

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) {
    final texts = _kotlinBaselineChildren(null);
    return {
      'import androidx.glance.layout.Row',
      'import androidx.glance.layout.Alignment',
      if (mainAxisAlignment != null) 'import androidx.glance.layout.Spacer',
      if (mainAxisAlignment.fillsMainAxis &&
          enclosingLinearAxis != HWAxis.horizontal)
        'import androidx.glance.layout.fillMaxWidth',
      if (_defeatsBaseline && children.any((c) => c.kotlinReportsBaseline))
        'import androidx.glance.layout.Box',
      if (texts != null) ...{
        'import androidx.glance.layout.Box',
        'import androidx.glance.layout.padding',
        'import es.antonborri.home_widget.HomeWidgetFonts',
        for (final text in texts.values) ...text.kotlinImports,
      },
      for (var index = 0; index < children.length; index++)
        ...children[index].kotlinImportsIn(
          _wrapsChild(index, texts) ? null : HWAxis.horizontal,
        ),
    };
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
    final texts = _kotlinBaselineChildren(context);
    for (final text in texts?.values ?? const <HWKotlinBaselineText>[]) {
      if (text.conflict case final conflict?) throw GeneratorError(conflict);
    }
    final pad = '    ' * indent;
    final buffer = StringBuffer();

    final align = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start ||
      HWCrossAxisAlignment.baseline =>
        'Alignment.Top',
      HWCrossAxisAlignment.center => 'Alignment.CenterVertically',
      HWCrossAxisAlignment.end => 'Alignment.Bottom',
    };

    // A row filling the width of the row it sits in would leave its siblings
    // nothing, so along that axis it asks for the room by weight.
    final fill = context?.enclosingLinearAxis == HWAxis.horizontal
        ? 'defaultWeight()'
        : 'fillMaxWidth()';
    final arguments = [
      if (mainAxisAlignment.fillsMainAxis) 'modifier = GlanceModifier.$fill',
      'verticalAlignment = $align',
    ].join(', ');
    buffer.writeln('${pad}Row($arguments) {');

    final childContext =
        (context ?? const HWEmitContext()).inLinear(HWAxis.horizontal);
    // The texts are keyed by child index, and the spacers an alignment adds are
    // not children; counting the calls is what keeps the two lined up.
    var index = 0;
    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent + 1,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) => _emitKotlinChild(
        child,
        childIndent,
        data,
        childContext,
        texts,
        index++,
      ),
      (pad) => '${pad}Spacer(modifier = GlanceModifier.defaultWeight())',
    );

    buffer.write('$pad}');
    return buffer.toString();
  }

  /// [child]'s Glance code, wrapped in a `Box` when the row takes its placement
  /// over from the layout.
  ///
  /// A child this row places is padded down to the row's baseline; one that
  /// only has to lose a baseline [_defeatsBaseline] would otherwise correct by
  /// gets a bare `Box`, whose `getBaseline()` is -1.
  String _emitKotlinChild(
    HWWidget child,
    int indent,
    String dataExpr,
    HWEmitContext? context,
    Map<int, HWKotlinBaselineText>? texts,
    int index,
  ) {
    if (!_wrapsChild(index, texts)) {
      return child.toKotlin(indent, dataExpr: dataExpr, context: context);
    }
    final placesChild = texts?.containsKey(index) ?? false;

    final pad = '    ' * indent;
    // The `Box` is what the row lays out now, so the child is no longer one of
    // its children.
    final inner = child.toKotlin(
      indent + 1,
      dataExpr: dataExpr,
      context: context?.inLinear(null),
    );
    final String box;
    if (placesChild) {
      final ascents =
          texts!.values.map((text) => text.ascent(dataExpr)).join(', ');
      final place = texts.keys.toList().indexOf(index);
      box = 'Box(modifier = GlanceModifier.padding(top = '
          'HomeWidgetFonts.baselinePadding(context, listOf($ascents), '
          '$place))) {';
    } else {
      box = 'Box {';
    }
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
