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
  });

  /// Human-readable description, used as the test name.
  final String description;

  /// Name of the Dart class annotated with `@HomeWidget`. The CLI derives
  /// generated artifact names from this (e.g. `${className}HomeWidget.kt`,
  /// `${className}HomeWidget/Widget.swift`).
  final String className;

  /// Full contents of the `widget.dart` file written into the test project.
  final String widgetSource;
}
