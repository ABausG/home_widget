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

class JsonDataGroup {
  final String key;
  final List<JsonDataField> children;

  const JsonDataGroup({
    required this.key,
    required this.children,
  });
}

class JsonDataField {
  final List<String> path;
  final HWDataType<dynamic> type;

  const JsonDataField({
    required this.path,
    required this.type,
  });
}

/// Specification for a home widget.
class WidgetSpec {
  /// The annotated configuration data.
  final HomeWidget data;

  /// The name of the Dart class (from annotated class).
  final String className;

  /// The data fields defined in the annotation.
  final List<HWDataType<dynamic>> dataFields;

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

  /// The effective widget tree, returning [widgetTree] if provided, or a
  /// generated default widget based on [dataFields].
  HWWidget get effectiveWidgetTree {
    if (widgetTree != null && widgetTree is! HWDataOnly) {
      return widgetTree!;
    }

    return HWColumn(
      children: [
        HWText.fixed(data.name),
        for (final field in dataFields)
          HWRow(
            children: [
              HWText.fixed('${field.key}: '),
              HWText(field),
            ],
          ),
      ],
    );
  }

  List<HWDataType<dynamic>> get primitiveDataFields =>
      dataFields.where((f) => f is! HWJson).toList();

  List<JsonDataGroup> get jsonDataGroups {
    final orderedKeys = <String>[];
    final groupedChildren = <String, List<JsonDataField>>{};

    for (final field in dataFields.whereType<HWJson>()) {
      if (!orderedKeys.contains(field.key)) {
        orderedKeys.add(field.key);
        groupedChildren[field.key] = <JsonDataField>[];
      }

      final leafType = field.leafType;
      final path = field.pathSegments;
      final existing = groupedChildren[field.key]!;
      if (existing.any((e) => _samePath(e.path, path) && e.type == leafType)) {
        continue;
      }
      groupedChildren[field.key]!.add(
        JsonDataField(
          path: path,
          type: leafType,
        ),
      );
    }

    return [
      for (final key in orderedKeys)
        JsonDataGroup(
          key: key,
          children: groupedChildren[key]!,
        ),
    ];
  }

  bool _samePath(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
