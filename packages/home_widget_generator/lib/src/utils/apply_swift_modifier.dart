/// Appends a SwiftUI view modifier (e.g. `.frame(...)`, `.background(...)`)
/// to [childCode].
///
/// SwiftUI lets you chain modifiers on a `View`, but a bare `if`/`switch`
/// statement is not a `View` expression and cannot be modified directly. When
/// [childCode] starts with `if ` or `switch `, this helper wraps the child in
/// a `Group { ... }` first — `Group` is a zero-cost `ViewBuilder` container
/// that turns the conditional into a modifiable expression.
///
/// A child that renders nothing — an `HWDataOnly`, or a wrapper around one —
/// is left alone: the modifier would otherwise dangle on its own line, where
/// SwiftUI reads it as a modifier of the preceding sibling.
///
/// - [childCode]: the already-generated Swift code for the child view. It may
///   begin with leading whitespace; the existing indentation is preserved.
/// - [modifier]: the modifier expression to append, including the leading dot
///   (e.g. `'.frame(maxWidth: .infinity, maxHeight: .infinity)'`).
/// - [indent]: the indentation level (4 spaces per level) used for any
///   `Group { ... }` braces and the appended modifier line.
String applySwiftModifier(String childCode, String modifier, int indent) {
  final pad = '    ' * indent;
  final trimmed = childCode.trimLeft();
  if (trimmed.isEmpty) return childCode;
  final needsWrap = trimmed.startsWith('if ') || trimmed.startsWith('switch ');

  if (!needsWrap) {
    return '$childCode\n$pad$modifier';
  }

  // Wrap the conditional in `Group { ... }`. We add one indent level on top
  // of the child's existing indentation so nested structure is preserved.
  const extra = '    ';
  final indented = childCode
      .split('\n')
      .map((line) => line.isEmpty ? line : '$extra$line')
      .join('\n');

  return '${pad}Group {\n$indented\n$pad}\n$pad$modifier';
}
