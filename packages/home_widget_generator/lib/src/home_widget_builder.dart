import 'widgets/hw_widget.dart';

/// The base class for defining a HomeWidget UI.
///
/// Subclasses must override [widgetBuilder] to provide the widget tree.
abstract class HomeWidgetBuilder {
  const HomeWidgetBuilder();

  /// Builds the widget tree for this HomeWidget.
  ///
  /// This getter or method must return a constant [HWWidget] expression.
  /// Example:
  /// ```dart
  /// @override
  /// HWWidget get widgetBuilder => const HWText.fixed('Hello World');
  /// ```
  HWWidget get widgetBuilder;
}
