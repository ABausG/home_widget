import '../models/widget_node.dart';
import '../models/widget_spec.dart';

/// Emits SwiftUI view code from a WidgetNode tree.
///
/// [dataExpr] is the Swift expression to access data fields.
/// For the entry view body established in v1.4, this is 'entry.widgetData'.
String emitSwiftWidgetBody(
  WidgetNode node, {
  required String dataExpr,
  int indent = 0,
}) {
  final pad = '    ' * indent; // 4-space indent to match Swift convention
  return switch (node) {
    TextNode(:final content) => '$pad${_emitSwiftText(content, dataExpr)}',
    ColumnNode(
      :final children,
      :final crossAxisAlignment,
      :final mainAxisAlignment,
    ) =>
      _emitSwiftStack(
        'VStack',
        children,
        dataExpr: dataExpr,
        indent: indent,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        isColumn: true,
      ),
    RowNode(
      :final children,
      :final crossAxisAlignment,
      :final mainAxisAlignment,
    ) =>
      _emitSwiftStack(
        'HStack',
        children,
        dataExpr: dataExpr,
        indent: indent,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        isColumn: false,
      ),
  };
}

String _emitSwiftText(ContentValue content, String dataExpr) {
  return switch (content) {
    StaticValue(:final value) => 'Text("${_escapeSwiftString(value)}")',
    DataRefValue(:final key, :final type) =>
      _emitSwiftDataText(key, type, dataExpr),
  };
}

String _emitSwiftDataText(String key, HWDataFieldType type, String dataExpr) {
  return switch (type) {
    HWDataFieldType.string => 'Text($dataExpr.$key ?? "")',
    HWDataFieldType.int_ =>
      'Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "0")',
    HWDataFieldType.double_ =>
      'Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "0.0")',
    HWDataFieldType.bool_ =>
      'Text($dataExpr.$key != nil ? "\\($dataExpr.$key!)" : "false")',
  };
}

String _escapeSwiftString(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

String _emitSwiftStack(
  String stackType,
  List<WidgetNode> children, {
  required String dataExpr,
  required int indent,
  CrossAxisAlignment? crossAxisAlignment,
  MainAxisAlignment? mainAxisAlignment,
  bool isColumn = true,
}) {
  final pad = '    ' * indent;
  final childPad = '    ' * (indent + 1);
  final buffer = StringBuffer();

  if (crossAxisAlignment != null) {
    final swiftAlign = isColumn
        ? _swiftVStackAlignment(crossAxisAlignment)
        : _swiftHStackAlignment(crossAxisAlignment);
    buffer.writeln('$pad$stackType(alignment: $swiftAlign) {');
  } else {
    buffer.writeln('$pad$stackType {');
  }

  // Emit children with Spacer() views for main-axis alignment
  switch (mainAxisAlignment) {
    case MainAxisAlignment.center:
      buffer.writeln('${childPad}Spacer()');
      for (final child in children) {
        buffer.writeln(
          emitSwiftWidgetBody(child, dataExpr: dataExpr, indent: indent + 1),
        );
      }
      buffer.writeln('${childPad}Spacer()');
    case MainAxisAlignment.end:
      buffer.writeln('${childPad}Spacer()');
      for (final child in children) {
        buffer.writeln(
          emitSwiftWidgetBody(child, dataExpr: dataExpr, indent: indent + 1),
        );
      }
    case MainAxisAlignment.spaceBetween:
      for (var i = 0; i < children.length; i++) {
        if (i > 0) buffer.writeln('${childPad}Spacer()');
        buffer.writeln(
          emitSwiftWidgetBody(
            children[i],
            dataExpr: dataExpr,
            indent: indent + 1,
          ),
        );
      }
    case MainAxisAlignment.spaceEvenly:
      buffer.writeln('${childPad}Spacer()');
      for (var i = 0; i < children.length; i++) {
        if (i > 0) buffer.writeln('${childPad}Spacer()');
        buffer.writeln(
          emitSwiftWidgetBody(
            children[i],
            dataExpr: dataExpr,
            indent: indent + 1,
          ),
        );
      }
      buffer.writeln('${childPad}Spacer()');
    case MainAxisAlignment.start:
    case null:
      for (final child in children) {
        buffer.writeln(
          emitSwiftWidgetBody(child, dataExpr: dataExpr, indent: indent + 1),
        );
      }
  }

  buffer.write('$pad}');
  return buffer.toString();
}

String _swiftVStackAlignment(CrossAxisAlignment align) => switch (align) {
      CrossAxisAlignment.start => '.leading',
      CrossAxisAlignment.center => '.center',
      CrossAxisAlignment.end => '.trailing',
    };

String _swiftHStackAlignment(CrossAxisAlignment align) => switch (align) {
      CrossAxisAlignment.start => '.top',
      CrossAxisAlignment.center => '.center',
      CrossAxisAlignment.end => '.bottom',
    };
