import 'widget_spec.dart';

/// Base class for all widget IR nodes.
sealed class WidgetNode {}

/// Represents an HWText in the IR.
class TextNode extends WidgetNode {
  /// The content value of this text node.
  final ContentValue content;

  /// Creates a [TextNode] with the given [content].
  TextNode({required this.content});
}

/// Represents an HWColumn in the IR.
class ColumnNode extends WidgetNode {
  /// The child widget nodes.
  final List<WidgetNode> children;

  /// Optional cross-axis alignment.
  final CrossAxisAlignment? crossAxisAlignment;

  /// Optional main-axis alignment.
  final MainAxisAlignment? mainAxisAlignment;

  /// Creates a [ColumnNode].
  ColumnNode({
    required this.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });
}

/// Represents an HWRow in the IR.
class RowNode extends WidgetNode {
  /// The child widget nodes.
  final List<WidgetNode> children;

  /// Optional cross-axis alignment.
  final CrossAxisAlignment? crossAxisAlignment;

  /// Optional main-axis alignment.
  final MainAxisAlignment? mainAxisAlignment;

  /// Creates a [RowNode].
  RowNode({
    required this.children,
    this.crossAxisAlignment,
    this.mainAxisAlignment,
  });
}

/// Cross-axis alignment in the CLI's IR model.
enum CrossAxisAlignment {
  /// Align to the start (leading/top).
  start,

  /// Align to the center.
  center,

  /// Align to the end (trailing/bottom).
  end,
}

/// Main-axis alignment in the CLI's IR model.
enum MainAxisAlignment {
  /// Align to the start.
  start,

  /// Align to the center.
  center,

  /// Align to the end.
  end,

  /// Space children evenly with space between them.
  spaceBetween,

  /// Space children evenly with equal space around them.
  spaceEvenly,
}

/// Base for content value types.
sealed class ContentValue {}

/// A hardcoded string literal from HWText.fixed('...').
class StaticValue extends ContentValue {
  /// The static string value.
  final String value;

  /// Creates a [StaticValue] with the given [value].
  StaticValue(this.value);
}

/// A data-bound reference from HWText.data(ref).
class DataRefValue extends ContentValue {
  /// The key name in the data map (e.g. 'countLabel').
  final String key;

  /// The HWDataFieldType from WidgetSpec.dataFields.
  final HWDataFieldType type;

  /// Creates a [DataRefValue] with the given [key] and [type].
  DataRefValue({required this.key, required this.type});
}
