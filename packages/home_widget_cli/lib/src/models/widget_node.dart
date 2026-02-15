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
