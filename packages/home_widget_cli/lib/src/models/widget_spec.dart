import 'package:home_widget_generator/home_widget_generator.dart';

/// Specification for interactivity callback configuration.
class InteractivitySpec {
  /// The import path for the callback function.
  final String import;

  /// The name of the callback function.
  final String callback;

  /// Creates a new [InteractivitySpec].
  const InteractivitySpec({required this.import, required this.callback});
}

/// Specification for a home widget.
class WidgetSpec {
  /// The annotated configuration data.
  final HomeWidget data;

  /// The name of the Dart class (from annotated class).
  final String className;

  /// The data fields defined in the annotation.
  final List<DataFieldSpec> dataFields;

  /// The interactivity configuration.
  final InteractivitySpec? interactivity;

  /// The widget tree definition (if any).
  final HWWidget? widgetTree;

  /// Creates a new [WidgetSpec].
  const WidgetSpec({
    required this.data,
    required this.className,
    this.dataFields = const [],
    this.interactivity,
    this.widgetTree,
  });
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSpec &&
          data == other.data &&
          className == other.className &&
          dataFields == other.dataFields &&
          interactivity == other.interactivity &&
          widgetTree == other.widgetTree;

  @override
  int get hashCode =>
      data.hashCode ^
      className.hashCode ^
      dataFields.hashCode ^
      interactivity.hashCode ^
      widgetTree.hashCode;
}

/// Specification for a single data field in a widget.
class DataFieldSpec {
  /// The key used to store and retrieve this field.
  final String key;

  /// The data type of the field.
  final HWDataType type;

  /// Creates a new [DataFieldSpec].
  const DataFieldSpec({required this.key, required this.type});
}
