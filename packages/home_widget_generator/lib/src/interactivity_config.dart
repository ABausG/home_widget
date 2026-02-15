/// Configuration for interactivity in the home widget.
class HomeWidgetInteractivityConfig {
  /// The import path to the file containing the callback.
  final String import;

  /// The name of the callback function.
  final String callback;

  const HomeWidgetInteractivityConfig({
    required this.import,
    required this.callback,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetInteractivityConfig &&
          import == other.import &&
          callback == other.callback;

  @override
  int get hashCode => import.hashCode ^ callback.hashCode;
}
