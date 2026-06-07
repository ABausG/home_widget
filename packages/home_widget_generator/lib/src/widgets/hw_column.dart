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

  @override
  Set<String> get kotlinImports {
    final imports = <String>{'import androidx.glance.layout.Column'};
    if (crossAxisAlignment != null) {
      imports.add('import androidx.glance.layout.Alignment');
    }
    if (mainAxisAlignment != null) {
      imports.add('import androidx.glance.layout.Spacer');
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

    return HWColumn(
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
  String toSwift(int indent, {required String dataExpr}) {
    final pad = '    ' * indent;
    final buffer = StringBuffer();
    final swiftAlign = switch (crossAxisAlignment) {
      HWCrossAxisAlignment.start => '.leading',
      HWCrossAxisAlignment.center => '.center',
      HWCrossAxisAlignment.end => '.trailing',
      null => null,
    };

    if (swiftAlign != null) {
      buffer.writeln('${pad}VStack(alignment: $swiftAlign) {');
    } else {
      buffer.writeln('${pad}VStack {');
    }

    _emitSwiftChildren(buffer, indent + 1, dataExpr);

    buffer.write('$pad}');
    return buffer.toString();
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final pad = '    ' * indent;
    final buffer = StringBuffer();
    final align = switch (crossAxisAlignment) {
      HWCrossAxisAlignment.start => 'Alignment.Start',
      HWCrossAxisAlignment.center => 'Alignment.CenterHorizontally',
      HWCrossAxisAlignment.end => 'Alignment.End',
      null => null,
    };

    if (align != null) {
      buffer.writeln('${pad}Column(horizontalAlignment = $align) {');
    } else {
      buffer.writeln('${pad}Column {');
    }

    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent + 1,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) => child.toKotlin(childIndent, dataExpr: data),
      (pad) => '${pad}Spacer(modifier = GlanceModifier.defaultWeight())',
    );

    buffer.write('$pad}');
    return buffer.toString();
  }

  void _emitSwiftChildren(StringBuffer buffer, int indent, String dataExpr) {
    _emitChildrenWithMainAxisAlignment(
      children,
      buffer,
      indent,
      dataExpr,
      mainAxisAlignment,
      (child, childIndent, data) => child.toSwift(childIndent, dataExpr: data),
      (pad) => '${pad}Spacer()',
    );
  }
}
