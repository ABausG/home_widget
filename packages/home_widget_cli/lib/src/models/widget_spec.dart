import 'package:home_widget_generator/home_widget_generator.dart';

/// Specification for a home widget.
class WidgetSpec {
  /// The annotated configuration data.
  final HomeWidget data;

  /// The name of the Dart class (from annotated class).
  final String className;

  const WidgetSpec({
    required this.data,
    required this.className,
  });

  String get name => data.name;
  String? get dartOutput => data.dartOutput;
  HomeWidgetAndroidConfiguration? get android => data.android;
  HomeWidgetIOSConfiguration? get ios => data.iOS;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSpec && data == other.data && className == other.className;

  @override
  int get hashCode => data.hashCode ^ className.hashCode;
}
