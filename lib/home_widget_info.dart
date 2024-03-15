/// Represents information about the pinned home widget.
class HomeWidgetInfo {
  /// Only iOS. The size of the widget: small, medium, or large.
  String? family;

  /// Only iOS. The string specified during creation of the widget’s configuration.
  String? kind;

  /// Only Android. Unique identifier for each instance of the widget, used for tracking individual widget usage.
  int? widgetId;

  /// Only Android. The [androidClassName] parameter represents the class name of the widget.
  String? androidClassName;

  /// Only Android. Loads the localized label to display to the user in the AppWidget picker.
  String? label;

  /// Constructs a [HomeWidgetInfo] object.
  HomeWidgetInfo({
    this.family,
    this.kind,
    this.widgetId,
    this.androidClassName,
    this.label,
  });

  /// Constructs a [HomeWidgetInfo] object from a map.
  ///
  /// The [data] parameter is a map that contains the widget information.
  factory HomeWidgetInfo.fromMap(Map<String, dynamic> data) {
    return HomeWidgetInfo(
      family: data['family'] as String?,
      kind: data['kind'] as String?,
      widgetId: data['widgetId'] as int?,
      androidClassName: data['androidClassName'] as String?,
      label: data['label'] as String?,
    );
  }

  @override
  String toString() {
    return 'HomeWidgetInfo{family: $family, kind: $kind, widgetId: $widgetId, androidClassName: $androidClassName, label: $label}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HomeWidgetInfo &&
        other.family == family &&
        other.kind == kind &&
        other.widgetId == widgetId &&
        other.androidClassName == androidClassName &&
        other.label == label;
  }

  @override
  int get hashCode {
    return family.hashCode ^
        kind.hashCode ^
        widgetId.hashCode ^
        androidClassName.hashCode ^
        label.hashCode;
  }
}
