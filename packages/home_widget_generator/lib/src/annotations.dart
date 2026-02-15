import 'interactivity_config.dart';
import 'types.dart';

/// Configuration for the Android widget.
class HomeWidgetAndroidConfiguration {
  /// The package name of the app.
  ///
  /// If null, the plugin will attempt to detect the package name from
  /// the Android project.
  final String? packageName;

  const HomeWidgetAndroidConfiguration({this.packageName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetAndroidConfiguration &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}

/// Configuration for the iOS widget.
class HomeWidgetIOSConfiguration {
  /// The app group ID for the widget.
  final String groupId;

  const HomeWidgetIOSConfiguration({required this.groupId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetIOSConfiguration && groupId == other.groupId;

  @override
  int get hashCode => groupId.hashCode;
}

/// Annotation for generating home_widget native code.
class HomeWidget {
  /// The name of the widget.
  final String name;

  /// The data fields for the widget.
  final Map<String, HWDataType>? data;

  /// The path to the generated Dart file.
  final String? dartOutput;

  /// Configuration for the Android widget.
  final HomeWidgetAndroidConfiguration? android;

  /// Configuration for the iOS widget.
  final HomeWidgetIOSConfiguration? iOS;

  /// Configuration for interactivity.
  final HomeWidgetInteractivityConfig? interactivity;

  const HomeWidget({
    required this.name,
    this.data,
    this.dartOutput,
    this.android,
    this.iOS,
    this.interactivity,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidget &&
          name == other.name &&
          data == other.data &&
          dartOutput == other.dartOutput &&
          android == other.android &&
          iOS == other.iOS &&
          interactivity == other.interactivity;

  @override
  int get hashCode =>
      name.hashCode ^
      data.hashCode ^
      dartOutput.hashCode ^
      android.hashCode ^
      iOS.hashCode ^
      interactivity.hashCode;
}
