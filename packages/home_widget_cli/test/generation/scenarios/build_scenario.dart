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
    this.hasLinks = false,
    this.hasButtons = false,
    this.files = const {},
    this.assetPaths = const [],
    this.fontFamilies = const {},
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
  /// it null expects the plain open-app click and, without [hasLinks], no
  /// manifest change.
  final String? expectedAndroidWidgetUrl;

  /// Whether [widgetSource] contains an `HWLink`, which needs the launch
  /// intent-filter whether or not the widget sets a URL.
  final bool hasLinks;

  /// Whether [widgetSource] contains an `HWButton`, which needs the plugin's
  /// background receiver on Android and the interaction intent, linked into
  /// the app and the extension, on iOS.
  final bool hasButtons;

  /// Dart files written into the test project ahead of generating, by their
  /// project-relative path: the library of an `onInteraction` function, and a
  /// `lib/main.dart` importing the generated helper so that the build compiles
  /// it.
  final Map<String, String> files;

  /// The URL, `homeWidget` parameter included, the generated iOS widget is
  /// expected to carry as its `widgetURL`, or null when it should carry none.
  final String? expectedIosWidgetUrl;

  /// Project-relative asset paths (e.g. `assets/logo.png`) that
  /// [widgetSource] references through `HWImageData.asset` or as a preview asset.
  ///
  /// The runner writes a placeholder PNG at each path and adds it to the
  /// project's `flutter: assets:` section, which the CLI's generate-time asset
  /// validation requires.
  final List<String> assetPaths;

  /// Font families [widgetSource] renders text in, mapped to the
  /// project-relative path of the file that ships them (e.g.
  /// `{'Chewy': 'assets/fonts/Chewy-Regular.ttf'}`).
  ///
  /// The runner copies a real font to each path and declares it under
  /// `flutter: fonts:`, which is what the CLI resolves a family through.
  final Map<String, String> fontFamilies;
}
