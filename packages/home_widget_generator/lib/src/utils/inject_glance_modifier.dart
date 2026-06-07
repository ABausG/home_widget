/// Helper to parse a typical Compose call (e.g. `Column {` or `Text(...)`)
/// and inject a modifier string (e.g. `fillMaxSize()`).
String injectGlanceModifier(String code, String modifier) {
  // We want to find the first Compose element like `Column(`, `Column {`, `Text(`.
  // If it already has arguments `Column(abc) {`, we inject `modifier = modifier, abc` or similar.

  final trimmed = code.trimLeft();
  final indentMatch = RegExp(r'^(\s*)').firstMatch(code);
  final indent = indentMatch?.group(1) ?? '';

  if (trimmed.startsWith('if (')) {
    final firstBraceIndex = code.indexOf('{');
    if (firstBraceIndex != -1) {
      int openBraces = 0;
      int firstBraceEnd = -1;
      for (int i = firstBraceIndex; i < code.length; i++) {
        if (code[i] == '{') {
          openBraces++;
        } else if (code[i] == '}') {
          openBraces--;
          if (openBraces == 0) {
            firstBraceEnd = i;
            break;
          }
        }
      }

      if (firstBraceEnd != -1) {
        final firstBlockContent =
            code.substring(firstBraceIndex + 1, firstBraceEnd);
        final injectedFirst = injectGlanceModifier(firstBlockContent, modifier);

        int secondBraceIndex = code.indexOf('{', firstBraceEnd + 1);
        int secondBraceEnd = -1;
        if (secondBraceIndex != -1) {
          openBraces = 0;
          for (int i = secondBraceIndex; i < code.length; i++) {
            if (code[i] == '{') {
              openBraces++;
            } else if (code[i] == '}') {
              openBraces--;
              if (openBraces == 0) {
                secondBraceEnd = i;
                break;
              }
            }
          }
        }

        if (secondBraceEnd != -1) {
          final secondBlockContent =
              code.substring(secondBraceIndex + 1, secondBraceEnd);
          final injectedSecond =
              injectGlanceModifier(secondBlockContent, modifier);

          return code.substring(0, firstBraceIndex + 1) +
              injectedFirst +
              code.substring(firstBraceEnd, secondBraceIndex + 1) +
              injectedSecond +
              code.substring(secondBraceEnd);
        } else {
          return code.substring(0, firstBraceIndex + 1) +
              injectedFirst +
              code.substring(firstBraceEnd);
        }
      }
    }
  }

  final compMatch =
      RegExp(r'^([A-Z][a-zA-Z0-9_]*)(?:\s*\((.*?)\))?').firstMatch(trimmed);
  if (compMatch != null) {
    final compName = compMatch.group(1);
    final args = compMatch.group(2);

    final hasBrace =
        trimmed.substring(compMatch.end).trimLeft().startsWith('{');

    String newArgs = '';
    if (args != null && args.isNotEmpty) {
      if (args.contains('GlanceModifier.')) {
        newArgs =
            args.replaceFirst('GlanceModifier.', 'GlanceModifier.$modifier.');
      } else if (args.contains('GlanceModifier')) {
        newArgs =
            args.replaceFirst('GlanceModifier', 'GlanceModifier.$modifier');
      } else {
        newArgs = 'modifier = GlanceModifier.$modifier, $args';
      }
    } else {
      newArgs = 'modifier = GlanceModifier.$modifier';
    }

    final rest = trimmed.substring(
      compMatch.end +
          (hasBrace ? trimmed.substring(compMatch.end).indexOf('{') + 1 : 0),
    );

    if (hasBrace) {
      return '$indent$compName($newArgs) {$rest';
    } else {
      return '$indent$compName($newArgs)$rest';
    }
  }

  // Fallback: if we can't find a direct Compose element (e.g. it's an if-statement), wrap it in a Box
  final lines = code.split('\n');
  final indentedLines =
      lines.map((l) => l.trimRight().isEmpty ? '' : '    $l').join('\n');
  return '${indent}Box(modifier = GlanceModifier.$modifier) {\n$indentedLines\n$indent}';
}

/// Wraps the widget tree in a full-size [Box] with [contentAlignment].
///
/// Used for the Android widget root so content is centered in the cell,
String wrapGlanceRootContent(
  String code, {
  required String modifier,
  String contentAlignment = 'Alignment.Center',
}) {
  final indentMatch = RegExp(r'^(\s*)').firstMatch(code);
  final indent = indentMatch?.group(1) ?? '';
  final lines = code.split('\n');
  final indentedLines =
      lines.map((l) => l.trimRight().isEmpty ? '' : '    $l').join('\n');
  return '${indent}Box(modifier = GlanceModifier.$modifier, contentAlignment = $contentAlignment) {\n$indentedLines\n$indent}';
}
