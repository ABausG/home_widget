/// A single end-to-end build scenario consumed by the platform-specific
/// integration tests in `test/generation/`.
///
/// Each scenario describes a complete `widget.dart` source file (containing
/// one `@HomeWidget(...)` annotated class) along with the metadata the
/// runners need to locate the generated platform artifact.
class BuildScenario {
  const BuildScenario({
    required this.description,
    required this.className,
    required this.widgetSource,
    this.expectsScheduledUpdateWiring = false,
    this.expectedAndroidWidgetUrl,
    this.expectedIosWidgetUrl,
    this.assetPaths = const [],
  });

  /// Human-readable description, used as the test name.
  final String description;

  /// Name of the Dart class annotated with `@HomeWidget`. The CLI derives
  /// generated artifact names from this (e.g. `${className}HomeWidget.kt`,
  /// `${className}HomeWidget/Widget.swift`).
  final String className;

  /// Full contents of the `widget.dart` file written into the test project.
  final String widgetSource;

  /// Whether the scenario has time-based fields, so the Android runner should
  /// assert that the CLI registered the plugin's scheduled update receiver in
  /// the app's `AndroidManifest.xml`.
  final bool expectsScheduledUpdateWiring;

  /// The URL, `homeWidget` parameter included, the generated Android widget is
  /// expected to open on tap, or null when the scenario configures none.
  ///
  /// A scenario setting this also expects the CLI to have declared the
  /// plugin's launch intent-filter on the app's launcher activity; one leaving
  /// it null expects the plain open-app click and no manifest change.
  final String? expectedAndroidWidgetUrl;

  /// The URL, `homeWidget` parameter included, the generated iOS widget is
  /// expected to carry as its `widgetURL`, or null when it should carry none.
  final String? expectedIosWidgetUrl;

  /// Project-relative asset paths (e.g. `assets/logo.png`) that
  /// [widgetSource] references through `HWImage.asset`.
  ///
  /// The runner writes a placeholder PNG at each path and adds it to the
  /// project's `flutter: assets:` section, which the CLI's generate-time asset
  /// validation requires.
  final List<String> assetPaths;
}
