/// Helper to parse a typical Compose call (e.g. `Column {` or `Text(...)`)
/// and inject a modifier string (e.g. `modifier = GlanceModifier.fillMaxSize()`).
String injectGlanceModifier(String code, String modifier) {
  // We want to find the first Compose element like `Column(`, `Column {`, `Text(`.
  // If it already has arguments `Column(abc) {`, we inject `modifier = modifier, abc` or similar.

  final trimmed = code.trimLeft();
  final indentMatch = RegExp(r'^(\s*)').firstMatch(code);
  final indent = indentMatch?.group(1) ?? '';

  final compMatch =
      RegExp(r'^([A-Z][a-zA-Z0-9_]*)(?:\s*\((.*?)\))?').firstMatch(trimmed);
  if (compMatch != null) {
    final compName = compMatch.group(1);
    final args = compMatch.group(2);

    final hasBrace =
        trimmed.substring(compMatch.end).trimLeft().startsWith('{');

    String newArgs = '';
    if (args != null && args.isNotEmpty) {
      newArgs = '$modifier, $args';
    } else {
      newArgs = modifier;
    }

    final rest = trimmed.substring(compMatch.end +
        (hasBrace ? trimmed.substring(compMatch.end).indexOf('{') + 1 : 0));

    if (hasBrace) {
      return '$indent$compName($newArgs) {$rest';
    } else {
      return '$indent$compName($newArgs)$rest';
    }
  }

  // Fallback: don't modify if we can't parse
  return code;
}
