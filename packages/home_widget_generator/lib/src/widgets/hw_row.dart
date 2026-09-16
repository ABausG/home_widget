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
  /// which renders both as baseline alignment; it leaves a centred one alone,
  /// and under [HWCrossAxisAlignment.baseline] the correction is the point.
  bool get _defeatsBaseline => switch (effectiveCrossAxisAlignment) {
        HWCrossAxisAlignment.start || HWCrossAxisAlignment.end => true,
        HWCrossAxisAlignment.center || HWCrossAxisAlignment.baseline => false,
      };

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
    final pad = '    ' * indent;
    final buffer = StringBuffer();

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
    buffer.writeln('${pad}Row($arguments) {');

    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent + 1,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) =>
          _emitKotlinChild(child, childIndent, data, context),
      (pad) => '${pad}Spacer(modifier = GlanceModifier.defaultWeight())',
    );

    buffer.write('$pad}');
    return buffer.toString();
  }

  /// [child]'s Glance code, wrapped in a bare `Box` when [_defeatsBaseline].
  String _emitKotlinChild(
    HWWidget child,
    int indent,
    String dataExpr,
    HWEmitContext? context,
  ) {
    if (!_defeatsBaseline || !child.kotlinReportsBaseline) {
      return child.toKotlin(indent, dataExpr: dataExpr, context: context);
    }

    final pad = '    ' * indent;
    final inner =
        child.toKotlin(indent + 1, dataExpr: dataExpr, context: context);
    return '''
${pad}Box {
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
