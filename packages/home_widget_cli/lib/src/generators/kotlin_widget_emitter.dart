import '../models/widget_node.dart';
import '../models/widget_spec.dart';

/// Emits Jetpack Glance Composable code from a WidgetNode tree.
///
/// [dataExpr] is the Kotlin expression to access data fields.
/// For the Glance widget established in v1.3, this is 'data' (or 'widgetData').
String emitKotlinWidgetBody(
  WidgetNode node, {
  required String dataExpr,
  int indent = 0,
}) {
  final pad = '    ' * indent; // 4-space indent to match Kotlin convention
  return switch (node) {
    TextNode(:final content) => '$pad${_emitKotlinText(content, dataExpr)}',
    ColumnNode(
      :final children,
      :final crossAxisAlignment,
      :final mainAxisAlignment,
    ) =>
      _emitKotlinLayout(
        'Column',
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
      _emitKotlinLayout(
        'Row',
        children,
        dataExpr: dataExpr,
        indent: indent,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        isColumn: false,
      ),
  };
}

String _emitKotlinText(ContentValue content, String dataExpr) {
  return switch (content) {
    StaticValue(:final value) => 'Text(text = "${_escapeKotlinString(value)}")',
    DataRefValue(:final key, :final type) =>
      _emitKotlinDataText(key, type, dataExpr),
  };
}

String _emitKotlinDataText(String key, HWDataFieldType type, String dataExpr) {
  return switch (type) {
    HWDataFieldType.string => 'Text(text = $dataExpr.$key ?: "")',
    HWDataFieldType.int_ => 'Text(text = ($dataExpr.$key?.toString() ?: "0"))',
    HWDataFieldType.double_ =>
      'Text(text = ($dataExpr.$key?.toString() ?: "0.0"))',
    HWDataFieldType.bool_ =>
      'Text(text = ($dataExpr.$key?.toString() ?: "false"))',
  };
}

String _escapeKotlinString(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\$', '\\\$');

String _emitKotlinLayout(
  String layoutType,
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
    final align = isColumn
        ? _glanceColumnAlignment(crossAxisAlignment)
        : _glanceRowAlignment(crossAxisAlignment);
    final param = isColumn
        ? 'horizontalAlignment = $align'
        : 'verticalAlignment = $align';
    buffer.writeln('$pad$layoutType($param) {');
  } else {
    buffer.writeln('$pad$layoutType {');
  }

  // Emit children with Spacer() composables for main-axis alignment
  switch (mainAxisAlignment) {
    case MainAxisAlignment.center:
      buffer.writeln('${childPad}Spacer()');
      for (final child in children) {
        buffer.writeln(
          emitKotlinWidgetBody(child, dataExpr: dataExpr, indent: indent + 1),
        );
      }
      buffer.writeln('${childPad}Spacer()');
    case MainAxisAlignment.end:
      buffer.writeln('${childPad}Spacer()');
      for (final child in children) {
        buffer.writeln(
          emitKotlinWidgetBody(child, dataExpr: dataExpr, indent: indent + 1),
        );
      }
    case MainAxisAlignment.spaceBetween:
      for (var i = 0; i < children.length; i++) {
        if (i > 0) buffer.writeln('${childPad}Spacer()');
        buffer.writeln(
          emitKotlinWidgetBody(
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
          emitKotlinWidgetBody(
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
          emitKotlinWidgetBody(child, dataExpr: dataExpr, indent: indent + 1),
        );
      }
  }

  buffer.write('$pad}');
  return buffer.toString();
}

String _glanceColumnAlignment(CrossAxisAlignment align) => switch (align) {
      CrossAxisAlignment.start => 'Alignment.Start',
      CrossAxisAlignment.center => 'Alignment.CenterHorizontally',
      CrossAxisAlignment.end => 'Alignment.End',
    };

String _glanceRowAlignment(CrossAxisAlignment align) => switch (align) {
      CrossAxisAlignment.start => 'Alignment.Top',
      CrossAxisAlignment.center => 'Alignment.CenterVertically',
      CrossAxisAlignment.end => 'Alignment.Bottom',
    };

/// Returns the set of Glance layout imports needed for the widget tree.
Set<String> collectKotlinLayoutImports(WidgetNode? node) {
  if (node == null) return {};
  final imports = <String>{};
  _walkForImports(node, imports);
  return imports;
}

void _walkForImports(WidgetNode node, Set<String> imports) {
  switch (node) {
    case ColumnNode(
        :final children,
        :final crossAxisAlignment,
        :final mainAxisAlignment,
      ):
      imports.add('import androidx.glance.layout.Column');
      if (crossAxisAlignment != null) {
        imports.add('import androidx.compose.ui.Alignment');
      }
      if (mainAxisAlignment != null) {
        imports.add('import androidx.glance.layout.Spacer');
      }
      for (final child in children) {
        _walkForImports(child, imports);
      }
    case RowNode(
        :final children,
        :final crossAxisAlignment,
        :final mainAxisAlignment,
      ):
      imports.add('import androidx.glance.layout.Row');
      if (crossAxisAlignment != null) {
        imports.add('import androidx.compose.ui.Alignment');
      }
      if (mainAxisAlignment != null) {
        imports.add('import androidx.glance.layout.Spacer');
      }
      for (final child in children) {
        _walkForImports(child, imports);
      }
    case TextNode():
      break;
  }
}
