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

  static HWRow fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    var childrenField = obj.getField('children');
    if (childrenField == null || childrenField.isNull) {
      childrenField = obj.getField('(super)')?.getField('children');
    }
    final children = childrenField?.toListValue()?.map((child) {
          return decoder.decodeRecursive(child);
        }).toList() ??
        [];

    final crossAxisAlignmentField = obj.getField('crossAxisAlignment');
    final mainAxisAlignmentField = obj.getField('mainAxisAlignment');

    return HWRow(
      children: children,
      crossAxisAlignment: WidgetValueDecoder.decodeEnum(
          crossAxisAlignmentField, HWCrossAxisAlignment.values),
      mainAxisAlignment: WidgetValueDecoder.decodeEnum(
          mainAxisAlignmentField, HWMainAxisAlignment.values),
    );
  }

  @override
  String toSwift(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
    final pad = '    ' * indent;
    final buffer = StringBuffer();
    final swiftAlign = switch (crossAxisAlignment) {
      HWCrossAxisAlignment.start => '.top',
      HWCrossAxisAlignment.center => '.center',
      HWCrossAxisAlignment.end => '.bottom',
      null => null,
    };

    if (swiftAlign != null) {
      buffer.writeln('${pad}HStack(alignment: $swiftAlign) {');
    } else {
      buffer.writeln('${pad}HStack {');
    }

    _emitSwiftChildren(buffer, indent + 1, dataExpr, dataFields);

    buffer.write('$pad}');
    return buffer.toString();
  }

  @override
  String toKotlin(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
    final pad = '    ' * indent;
    final buffer = StringBuffer();
    final align = switch (crossAxisAlignment) {
      HWCrossAxisAlignment.start => 'Alignment.Top',
      HWCrossAxisAlignment.center => 'Alignment.CenterVertically',
      HWCrossAxisAlignment.end => 'Alignment.Bottom',
      null => null,
    };

    if (align != null) {
      buffer.writeln('${pad}Row(verticalAlignment = $align) {');
    } else {
      buffer.writeln('${pad}Row {');
    }

    _emitKotlinChildren(buffer, indent + 1, dataExpr, dataFields);

    buffer.write('$pad}');
    return buffer.toString();
  }

  void _emitKotlinChildren(StringBuffer buffer, int indent, String dataExpr,
      Map<String, HWDataType> dataFields) {
    final childPad = '    ' * indent;

    switch (mainAxisAlignment) {
      case HWMainAxisAlignment.center:
        buffer.writeln('${childPad}Spacer()');
        for (final child in children) {
          buffer.writeln(child.toKotlin(indent,
              dataExpr: dataExpr, dataFields: dataFields));
        }
        buffer.writeln('${childPad}Spacer()');
      case HWMainAxisAlignment.end:
        buffer.writeln('${childPad}Spacer()');
        for (final child in children) {
          buffer.writeln(child.toKotlin(indent,
              dataExpr: dataExpr, dataFields: dataFields));
        }
      case HWMainAxisAlignment.spaceBetween:
        for (var i = 0; i < children.length; i++) {
          if (i > 0) buffer.writeln('${childPad}Spacer()');
          buffer.writeln(children[i]
              .toKotlin(indent, dataExpr: dataExpr, dataFields: dataFields));
        }
      case HWMainAxisAlignment.spaceEvenly:
        buffer.writeln('${childPad}Spacer()');
        for (var i = 0; i < children.length; i++) {
          if (i > 0) buffer.writeln('${childPad}Spacer()');
          buffer.writeln(children[i]
              .toKotlin(indent, dataExpr: dataExpr, dataFields: dataFields));
        }
        buffer.writeln('${childPad}Spacer()');
      case HWMainAxisAlignment.start:
      case null:
        for (final child in children) {
          buffer.writeln(child.toKotlin(indent,
              dataExpr: dataExpr, dataFields: dataFields));
        }
    }
  }

  void _emitSwiftChildren(StringBuffer buffer, int indent, String dataExpr,
      Map<String, HWDataType> dataFields) {
    final childPad = '    ' * indent;

    switch (mainAxisAlignment) {
      case HWMainAxisAlignment.center:
        buffer.writeln('${childPad}Spacer()');
        for (final child in children) {
          buffer.writeln(child.toSwift(indent,
              dataExpr: dataExpr, dataFields: dataFields));
        }
        buffer.writeln('${childPad}Spacer()');
      case HWMainAxisAlignment.end:
        buffer.writeln('${childPad}Spacer()');
        for (final child in children) {
          buffer.writeln(child.toSwift(indent,
              dataExpr: dataExpr, dataFields: dataFields));
        }
      case HWMainAxisAlignment.spaceBetween:
        for (var i = 0; i < children.length; i++) {
          if (i > 0) buffer.writeln('${childPad}Spacer()');
          buffer.writeln(children[i]
              .toSwift(indent, dataExpr: dataExpr, dataFields: dataFields));
        }
      case HWMainAxisAlignment.spaceEvenly:
        buffer.writeln('${childPad}Spacer()');
        for (var i = 0; i < children.length; i++) {
          if (i > 0) buffer.writeln('${childPad}Spacer()');
          buffer.writeln(children[i]
              .toSwift(indent, dataExpr: dataExpr, dataFields: dataFields));
        }
        buffer.writeln('${childPad}Spacer()');
      case HWMainAxisAlignment.start:
      case null:
        for (final child in children) {
          buffer.writeln(child.toSwift(indent,
              dataExpr: dataExpr, dataFields: dataFields));
        }
    }
  }
}
