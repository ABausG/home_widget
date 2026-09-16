part of 'hw_widget.dart';

/// A vertical layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI VStack and Glance Column.
class HWColumn extends HWMultiChildWidget {
  final HWCrossAxisAlignment? crossAxisAlignment;
  final HWMainAxisAlignment? mainAxisAlignment;

  const HWColumn({
    required super.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });

  /// The alignment this column renders with, always emitted so that neither
  /// platform falls back to its own default.
  ///
  /// `baseline` lines up along a horizontal cross axis, which a column has no
  /// baseline on; [fromDartObject] rejects it, and both emitters centre on it.
  HWCrossAxisAlignment get effectiveCrossAxisAlignment =>
      crossAxisAlignment ?? HWCrossAxisAlignment.center;

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.layout.Column',
        'import androidx.glance.layout.Alignment',
        if (mainAxisAlignment != null) 'import androidx.glance.layout.Spacer',
        if (mainAxisAlignment.fillsMainAxis &&
            enclosingLinearAxis != HWAxis.vertical)
          'import androidx.glance.layout.fillMaxHeight',
        for (final child in children) ...child.kotlinImportsIn(HWAxis.vertical),
      };

  static HWColumn fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final childrenField = WidgetValueDecoder.getField(obj, 'children');
    final listValue = childrenField?.toListValue();
    if (listValue == null) {
      // coverage:ignore-start
      throw GeneratorError('HWColumn: children parameter is required');
      // coverage:ignore-end
    }

    final children = listValue.map(decoder.decodeRecursive).toList();

    final crossAxisAlignmentField = obj.getField('crossAxisAlignment');
    final mainAxisAlignmentField = obj.getField('mainAxisAlignment');

    final crossAxisAlignment = WidgetValueDecoder.decodeEnum(
      crossAxisAlignmentField,
      HWCrossAxisAlignment.values,
    );
    if (crossAxisAlignment == HWCrossAxisAlignment.baseline) {
      throw GeneratorError(
        'HWColumn cannot use HWCrossAxisAlignment.baseline. Baseline alignment '
        'lines up the text baselines along a horizontal cross axis, so it only '
        'applies to HWRow.',
      );
    }

    return HWColumn(
      children: children,
      crossAxisAlignment: crossAxisAlignment,
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
    final swiftAlign = switch (effectiveCrossAxisAlignment) {
      HWCrossAxisAlignment.start => '.leading',
      HWCrossAxisAlignment.end => '.trailing',
      HWCrossAxisAlignment.center || HWCrossAxisAlignment.baseline => '.center',
    };

    buffer.writeln('${pad}VStack(alignment: $swiftAlign) {');

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
      HWCrossAxisAlignment.start => 'Alignment.Start',
      HWCrossAxisAlignment.end => 'Alignment.End',
      HWCrossAxisAlignment.center ||
      HWCrossAxisAlignment.baseline =>
        'Alignment.CenterHorizontally',
    };

    // A column filling the height of the column it sits in would leave its
    // siblings nothing, so along that axis it asks for the room by weight.
    final fill = context?.enclosingLinearAxis == HWAxis.vertical
        ? 'defaultWeight()'
        : 'fillMaxHeight()';
    final arguments = [
      if (mainAxisAlignment.fillsMainAxis) 'modifier = GlanceModifier.$fill',
      'horizontalAlignment = $align',
    ].join(', ');
    buffer.writeln('${pad}Column($arguments) {');

    final childContext =
        (context ?? const HWEmitContext()).inLinear(HWAxis.vertical);
    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent + 1,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) =>
          child.toKotlin(childIndent, dataExpr: data, context: childContext),
      (pad) => '${pad}Spacer(modifier = GlanceModifier.defaultWeight())',
    );

    buffer.write('$pad}');
    return buffer.toString();
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
