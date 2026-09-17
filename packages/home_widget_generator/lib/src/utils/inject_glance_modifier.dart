/// The start and end index of the argument list opening after [start], or null
/// when the next non-space character is not `(`.
///
/// Parentheses are balanced and string literals skipped, so a call spread over
/// several lines or holding a nested call reports its own closing bracket
/// rather than the first one it runs into.
(int, int)? _argumentRange(String code, int start) {
  final open = RegExp(r'\s*\(').matchAsPrefix(code, start);
  if (open == null) return null;

  var depth = 0;
  var index = open.end - 1;
  while (index < code.length) {
    final char = code[index];
    if (char == '"') {
      index++;
      while (index < code.length && code[index] != '"') {
        if (code[index] == r'\') index++;
        index++;
      }
    } else if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return (open.end, index);
    }
    index++;
  }
  return null;
}

/// Matches the separator between two branches of an `if` chain, i.e. the
/// `} else {` / `} else if (...) {` glue (the trailing `{` excluded).
final _elseSeparator = RegExp(r'^\}\s*else\b[^{]*$', dotAll: true);

/// Returns the index of the `}` matching the `{` at [openIndex], or `-1`.
///
/// Braces inside a Kotlin string or character literal are text, not structure,
/// so a branch rendering `Text(text = "}")` still finds its own closing brace.
int _matchingBrace(String code, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < code.length; i++) {
    final char = code[i];
    if (char == '"' || char == "'") {
      i = _endOfLiteral(code, i);
      continue;
    }
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Returns the index of the quote closing the literal opened at [openIndex],
/// or the last index of [code] when the literal is never closed.
int _endOfLiteral(String code, int openIndex) {
  final quote = code[openIndex];
  for (var i = openIndex + 1; i < code.length; i++) {
    if (code[i] == r'\') {
      i++;
      continue;
    }
    if (code[i] == quote) return i;
  }
  return code.length - 1;
}

/// Injects [modifier] into every branch block of an `if` / `else if` / `else`
/// chain, recursing into nested branches.
///
/// Returns null when [code] holds no brace-delimited branch, so the caller can
/// fall back to its other strategies.
String? _injectIntoIfBranches(String code, String modifier) {
  var cursor = 0;
  final buffer = StringBuffer();

  while (true) {
    final open = code.indexOf('{', cursor);
    if (open == -1) break;

    final close = _matchingBrace(code, open);
    if (close == -1) break;

    buffer
      ..write(code.substring(cursor, open + 1))
      ..write(injectGlanceModifier(code.substring(open + 1, close), modifier));
    cursor = close;

    // Continue only while the blocks are chained by `else` / `else if`.
    final nextOpen = code.indexOf('{', close);
    if (nextOpen == -1) break;
    if (!_elseSeparator.hasMatch(code.substring(close, nextOpen))) break;
  }

  if (buffer.isEmpty) return null;

  buffer.write(code.substring(cursor));
  return buffer.toString();
}

/// Injects [modifier] into the body of every `… -> { }` branch of a `when`
/// statement, recursing into nested branches.
///
/// Returns null when [code] holds no such branch.
String? _injectIntoWhenBranches(String code, String modifier) {
  final bodyOpen = code.indexOf('{');
  if (bodyOpen == -1) return null;

  final bodyClose = _matchingBrace(code, bodyOpen);
  if (bodyClose == -1) return null;

  final buffer = StringBuffer();
  var cursor = 0;

  while (true) {
    final arrow = code.indexOf('->', cursor);
    if (arrow == -1 || arrow > bodyClose) break;

    final open = code.indexOf('{', arrow);
    if (open == -1 || open > bodyClose) break;

    final close = _matchingBrace(code, open);
    if (close == -1) break;

    buffer
      ..write(code.substring(cursor, open + 1))
      ..write(injectGlanceModifier(code.substring(open + 1, close), modifier));
    cursor = close;
  }

  if (buffer.isEmpty) return null;

  buffer.write(code.substring(cursor));
  return buffer.toString();
}

/// The fill modifiers `fillMaxSize()` already asks for both of.
const _fillAxisModifiers = ['fillMaxWidth()', 'fillMaxHeight()'];

const _fillBothAxes = 'fillMaxSize()';

/// The token a modifier chain opens with.
const _modifierToken = 'GlanceModifier';

/// [chain] without the fill modifiers [modifier] makes redundant.
///
/// Both axes at once say everything one of them does, so a chain keeps the one
/// that asks for more rather than carrying both.
String _withoutRedundantFills(String chain, String modifier) {
  if (modifier != _fillBothAxes) return chain;
  var kept = chain;
  for (final axis in _fillAxisModifiers) {
    kept = kept.replaceAll('.$axis', '');
  }
  return kept;
}

/// The start and end index of the `GlanceModifier` chain in [args], or null
/// when no argument is one.
///
/// The chain runs to the end of the argument holding it, so the text an
/// argument beside it carries — `text = "a.fillMaxWidth()"` — is neither read
/// as a modifier nor rewritten. String literals are skipped, and a `,` only
/// ends the argument outside the brackets of a call in the chain.
(int, int)? _modifierChainRange(String args) {
  var start = -1;
  var depth = 0;

  for (var index = 0; index < args.length; index++) {
    final char = args[index];
    if (char == '"') {
      index = _endOfLiteral(args, index);
      continue;
    }
    if (start == -1) {
      if (args.startsWith(_modifierToken, index)) start = index;
      continue;
    }
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
    } else if (char == ',' && depth == 0) {
      return (start, index);
    }
  }

  return start == -1 ? null : (start, args.length);
}

/// Helper to parse a typical Compose call (e.g. `Column {` or `Text(...)`)
/// and inject a modifier string (e.g. `fillMaxSize()`).
String injectGlanceModifier(String code, String modifier) {
  // We want to find the first Compose element like `Column(`, `Column {`, `Text(`.
  // If it already has arguments `Column(abc) {`, we inject `modifier = modifier, abc` or similar.

  final trimmed = code.trimLeft();
  final indentMatch = RegExp(r'^(\s*)').firstMatch(code);
  final indent = indentMatch?.group(1) ?? '';

  if (trimmed.startsWith('if (')) {
    final injected = _injectIntoIfBranches(code, modifier);
    if (injected != null) return injected;
  }

  if (trimmed.startsWith('when (')) {
    final injected = _injectIntoWhenBranches(code, modifier);
    if (injected != null) return injected;
  }

  final compMatch = RegExp(r'^[A-Z][a-zA-Z0-9_]*').firstMatch(trimmed);
  if (compMatch != null) {
    final compName = compMatch.group(0);
    final argRange = _argumentRange(trimmed, compMatch.end);
    final declared =
        argRange == null ? null : trimmed.substring(argRange.$1, argRange.$2);
    final callEnd = argRange == null ? compMatch.end : argRange.$2 + 1;

    final chainRange = declared == null ? null : _modifierChainRange(declared);
    final chain = chainRange == null
        ? null
        : declared!.substring(chainRange.$1, chainRange.$2);

    // One axis of a chain already filling both says nothing more.
    if (_fillAxisModifiers.contains(modifier) &&
        (chain?.contains(_fillBothAxes) ?? false)) {
      return code;
    }
    final args = chainRange == null
        ? declared ?? ''
        : declared!.replaceRange(
            chainRange.$1,
            chainRange.$2,
            _withoutRedundantFills(chain!, modifier),
          );

    final hasBrace = trimmed.substring(callEnd).trimLeft().startsWith('{');

    String newArgs = '';
    if (args.isEmpty) {
      newArgs = 'modifier = GlanceModifier.$modifier';
    } else if (chainRange != null) {
      final head = args.substring(0, chainRange.$1);
      final tail = args.substring(chainRange.$1 + _modifierToken.length);
      newArgs = '$head$_modifierToken.$modifier$tail';
    } else {
      newArgs = 'modifier = GlanceModifier.$modifier, $args';
    }

    final rest = trimmed.substring(
      callEnd + (hasBrace ? trimmed.substring(callEnd).indexOf('{') + 1 : 0),
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
