/// Represents information about the pinned home widget.
class HomeWidgetInfo {
  /// Only iOS. The size of the widget: small, medium, or large.
  String? iOSFamily;

  /// Only iOS. The string specified during creation of the widget’s configuration.
  String? iOSKind;

  /// Only Android. Unique identifier for each instance of the widget, used for tracking individual widget usage.
  int? androidWidgetId;

  /// Only Android. The [androidClassName] parameter represents the class name of the widget.
  String? androidClassName;

  /// Only Android. Loads the localized label to display to the user in the AppWidget picker.
  String? androidLabel;

  /// Only iOS. The configuration of the widget if setup as a configurable widget.
  /// In case `WidgetConfigurationIntent` is used, the configuration needs to passed to the Widget
  Map<String, dynamic>? configuration;

  /// Constructs a [HomeWidgetInfo] object.
  HomeWidgetInfo({
    this.iOSFamily,
    this.iOSKind,
    this.androidWidgetId,
    this.androidClassName,
    this.androidLabel,
    this.configuration,
  });

  /// Constructs a [HomeWidgetInfo] object from a map.
  ///
  /// The [data] parameter is a map that contains the widget information.
  factory HomeWidgetInfo.fromMap(Map<String, dynamic> data) {
    return HomeWidgetInfo(
      iOSFamily: data['family'] as String?,
      iOSKind: data['kind'] as String?,
      androidWidgetId: data['widgetId'] as int?,
      androidClassName: data['androidClassName'] as String?,
      androidLabel: data['label'] as String?,
      configuration: ((data['configuration'] as Map<dynamic, dynamic>?)
            ?..removeWhere((key, _) => key is! String))
          ?.cast<String, dynamic>(),
    );
  }

  @override
  String toString() {
    return 'HomeWidgetInfo('
        'iOSFamily: $iOSFamily, '
        'iOSKind: $iOSKind, '
        'androidWidgetId: $androidWidgetId, '
        'androidClassName: $androidClassName, '
        'androidLabel: $androidLabel, '
        'configuration: $configuration'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HomeWidgetInfo &&
        other.iOSFamily == iOSFamily &&
        other.iOSKind == iOSKind &&
        other.androidWidgetId == androidWidgetId &&
        other.androidClassName == androidClassName &&
        other.androidLabel == androidLabel &&
        other.configuration == configuration;
  }

  @override
  int get hashCode {
    return iOSFamily.hashCode ^
        iOSKind.hashCode ^
        androidWidgetId.hashCode ^
        androidClassName.hashCode ^
        androidLabel.hashCode ^
        configuration.hashCode;
  }
}
