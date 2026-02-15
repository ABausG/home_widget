import 'dart:io';

import 'android_scaffold.dart';
import 'ios_scaffold.dart';

/// Creates placeholder native file structures for a home screen widget.
///
/// Platform-specific implementations live in `android_scaffold.dart` and
/// `ios_scaffold.dart`.
final class WidgetScaffold {
  /// Creates a scaffold instance.
  WidgetScaffold({required this.projectRoot, required this.widgetClassName});

  /// The directory where the CLI was invoked (expected to be a Flutter app
  /// root).
  final Directory projectRoot;

  /// Widget class name, e.g. `ExampleHomeWidget`.
  final String widgetClassName;

  /// Create Android placeholders using Jetpack Compose (Glance).
  Future<void> createAndroid() async {
    final scaffold = AndroidWidgetScaffold(
      projectRoot: projectRoot,
      widgetClassName: widgetClassName,
    );
    await scaffold.run();
  }

  /// Create iOS widget-extension placeholders.
  Future<void> createIos({required String appGroupId}) async {
    final scaffold = IosWidgetScaffold(
      projectRoot: projectRoot,
      widgetClassName: widgetClassName,
    );
    await scaffold.run(appGroupId: appGroupId);
  }
}
