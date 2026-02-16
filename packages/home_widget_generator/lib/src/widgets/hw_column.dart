part of 'hw_widget.dart';

/// A vertical layout widget for use in widgetBuilder.
///
/// Maps to SwiftUI VStack and Glance Column.
class HWColumn extends HWWidget {
  final List<HWWidget> children;
  final HWCrossAxisAlignment? crossAxisAlignment;
  final HWMainAxisAlignment? mainAxisAlignment;

  const HWColumn({
    required this.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });

  @override
  String toSwift(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
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

    _emitSwiftChildren(buffer, indent + 1, dataExpr, dataFields);

    buffer.write('$pad})');
    return buffer.toString();
  }

  @override
  String toKotlin(int indent,
      {required String dataExpr,
      Map<String, HWDataType> dataFields = const {}}) {
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
