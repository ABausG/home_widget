/// A common interface for elements that can generate Swift and Kotlin code
/// with their associated imports.
abstract interface class HWGeneratable {
  /// The set of Kotlin imports required by this element.
  Set<String> get kotlinImports;

  /// The set of Swift view declarations/modifiers required by this element
  /// (e.g., `@Environment(\\.colorScheme) var colorScheme`).
  Set<String> get swiftViewModifiers;

  /// Generates the SwiftUI code.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Swift expression to access data fields (e.g. "entry.widgetData").
  String toSwift(
    int indent, {
    required String dataExpr,
  });

  /// Generates the Kotlin code.
  /// [indent] is the number of indentation levels (4 spaces each).
  /// [dataExpr] is the Kotlin expression to access data fields.
  String toKotlin(
    int indent, {
    required String dataExpr,
  });
}
