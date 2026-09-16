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

  /// Whether the main axis is aligned with spacers, which only take room in a
  /// `Column` that fills its height.
  bool get _fillsMainAxis => switch (mainAxisAlignment) {
        HWMainAxisAlignment.center ||
        HWMainAxisAlignment.end ||
        HWMainAxisAlignment.spaceBetween ||
        HWMainAxisAlignment.spaceEvenly =>
          true,
        HWMainAxisAlignment.start || null => false,
      };

  @override
  Set<String> get kotlinImports {
    final imports = <String>{
      'import androidx.glance.layout.Column',
      'import androidx.glance.layout.Alignment',
    };
    if (mainAxisAlignment != null) {
      imports.add('import androidx.glance.layout.Spacer');
    }
    if (_fillsMainAxis) {
      imports.add('import androidx.glance.layout.fillMaxHeight');
    }
    return imports.union(super.kotlinImports);
  }

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
    final swiftAlign = switch (crossAxisAlignment) {
      HWCrossAxisAlignment.start => '.leading',
      HWCrossAxisAlignment.end => '.trailing',
      HWCrossAxisAlignment.center ||
      HWCrossAxisAlignment.baseline ||
      null =>
        '.center',
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
    final align = switch (crossAxisAlignment) {
      HWCrossAxisAlignment.start => 'Alignment.Start',
      HWCrossAxisAlignment.end => 'Alignment.End',
      HWCrossAxisAlignment.center ||
      HWCrossAxisAlignment.baseline ||
      null =>
        'Alignment.CenterHorizontally',
    };

    final arguments = [
      if (_fillsMainAxis) 'modifier = GlanceModifier.fillMaxHeight()',
      'horizontalAlignment = $align',
    ].join(', ');
    buffer.writeln('${pad}Column($arguments) {');

    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent + 1,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) =>
          child.toKotlin(childIndent, dataExpr: data, context: context),
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
