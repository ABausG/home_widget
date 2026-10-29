/// A value read from an OpenStep ASCII property list, with its source span.
sealed class PbxNode {
  const PbxNode(this.start, this.end);

  /// Offset of the first character of the value.
  final int start;

  /// Offset just past the last character of the value.
  final int end;

  /// Offset just past the value and the comment following it.
  int get endWithComment => end;
}

/// A `/* … */` comment.
final class PbxComment {
  /// Creates a comment spanning [start] to [end] whose body is [text].
  const PbxComment(this.start, this.end, this.text);

  /// Offset of the opening `/*`.
  final int start;

  /// Offset just past the closing `*/`.
  final int end;

  /// The body between the delimiters, trimmed.
  final String text;
}

/// A quoted or unquoted string.
final class PbxString extends PbxNode {
  /// Creates a string node.
  const PbxString(super.start, super.end, {required this.value, this.comment});

  /// The string with quotes removed and escapes resolved.
  final String value;

  /// The comment following the string on the same line, the title Xcode writes
  /// after an object id.
  final PbxComment? comment;

  @override
  int get endWithComment => comment?.end ?? end;
}

/// A `<hex data>` value.
final class PbxData extends PbxNode {
  /// Creates a data node.
  const PbxData(super.start, super.end);
}

/// One element of a [PbxArray].
final class PbxArrayItem {
  /// Creates an array item.
  const PbxArrayItem(this.value, this.end);

  /// The element.
  final PbxNode value;

  /// Offset just past the separating comma, or [textEnd] when the last element
  /// has none.
  final int end;

  /// Offset of the element.
  int get start => value.start;

  /// Offset just past the element and the comment following it.
  int get textEnd => value.endWithComment;

  /// The element's string value, or null when it is not a string.
  String? get string {
    final node = value;
    return node is PbxString ? node.value : null;
  }
}

/// A `( … )` array.
final class PbxArray extends PbxNode {
  /// Creates an array node spanning `(` to `)`.
  const PbxArray(super.start, super.end, this.items);

  /// The elements in source order.
  final List<PbxArrayItem> items;

  /// The string elements, in source order.
  List<String> get strings => [
        for (final item in items)
          if (item.string != null) item.string!,
      ];
}

/// One `key = value;` entry of a [PbxDict].
final class PbxDictEntry {
  /// Creates a dictionary entry.
  const PbxDictEntry(this.key, this.value, this.end);

  /// The key.
  final PbxString key;

  /// The value.
  final PbxNode value;

  /// Offset just past the terminating `;`.
  final int end;

  /// Offset of the key, which is where the entry starts.
  int get start => key.start;
}

/// A `{ … }` dictionary.
final class PbxDict extends PbxNode {
  /// Creates a dictionary node spanning `{` to `}`.
  const PbxDict(super.start, super.end, this.entries);

  /// The entries in source order.
  final List<PbxDictEntry> entries;

  /// The last entry named [key], the one a duplicated key resolves to.
  PbxDictEntry? entry(String key) =>
      entries.where((entry) => entry.key.value == key).lastOrNull;

  /// The value of [key].
  PbxNode? operator [](String key) => entry(key)?.value;

  /// The value of [key] when it is a string.
  String? string(String key) {
    final value = this[key];
    return value is PbxString ? value.value : null;
  }

  /// The value of [key] when it is an array.
  PbxArray? array(String key) {
    final value = this[key];
    return value is PbxArray ? value : null;
  }

  /// The value of [key] when it is a dictionary.
  PbxDict? dict(String key) {
    final value = this[key];
    return value is PbxDict ? value : null;
  }
}

/// The result of [parsePbxPlist].
final class PbxParseResult {
  /// Creates a parse result.
  const PbxParseResult(this.root, this.comments);

  /// The top-level dictionary.
  final PbxDict root;

  /// Every `/* … */` comment in the file, in source order.
  final List<PbxComment> comments;
}

/// Parses the OpenStep ASCII property list a `project.pbxproj` is written in.
///
/// Throws a [FormatException] naming the line of the first thing it cannot
/// read.
PbxParseResult parsePbxPlist(String text) => _Parser(text).parse();

final class _Parser {
  _Parser(this.text);

  final String text;
  final List<PbxComment> comments = [];
  int pos = 0;

  static final RegExp _xmlOrJson =
      RegExp(r'<\?xml|<!DOCTYPE|<plist|\{\s*"(?:[^"\\]|\\.)*"\s*:');

  PbxParseResult parse() {
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) pos = 1;
    _skip();
    if (_xmlOrJson.matchAsPrefix(text, pos) != null) {
      throw const FormatException(
        'The file is an XML or JSON property list, not in the format Xcode '
        'writes; opening and saving the project in Xcode restores it',
      );
    }
    if (!_at('{')) _fail('Expected "{" to open the top-level dictionary');
    final root = _dict();
    _skip();
    if (pos < text.length) {
      _fail('Unexpected "${text[pos]}" after the top-level dictionary');
    }
    return PbxParseResult(root, comments);
  }

  bool _at(String char) => pos < text.length && text[pos] == char;

  Never _fail(String message, [int? offset]) {
    final at = offset ?? pos;
    final before = text.substring(0, at.clamp(0, text.length));
    final line = '\n'.allMatches(before).length + 1;
    final column = at - (before.lastIndexOf('\n') + 1) + 1;
    throw FormatException('$message (line $line, column $column)', null, at);
  }

  void _skip() {
    while (pos < text.length) {
      final char = text.codeUnitAt(pos);
      if (char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D) {
        pos++;
      } else if (text.startsWith('/*', pos)) {
        _blockComment();
      } else if (text.startsWith('//', pos)) {
        final newline = text.indexOf('\n', pos);
        pos = newline == -1 ? text.length : newline + 1;
      } else {
        return;
      }
    }
  }

  PbxComment _blockComment() {
    final start = pos;
    final close = text.indexOf('*/', pos + 2);
    if (close == -1) _fail('Unterminated comment', start);
    pos = close + 2;
    final comment =
        PbxComment(start, pos, text.substring(start + 2, close).trim());
    comments.add(comment);
    return comment;
  }

  PbxComment? _trailingComment() {
    var i = pos;
    while (i < text.length && (text[i] == ' ' || text[i] == '\t')) {
      i++;
    }
    if (!text.startsWith('/*', i)) return null;
    pos = i;
    return _blockComment();
  }

  PbxNode _value(String what) {
    _skip();
    if (pos >= text.length) _fail('Unexpected end of file, expected $what');
    final char = text[pos];
    if (char == '{') return _dict();
    if (char == '(') return _array();
    if (char == '<') return _data();
    if (char == '"' || _isUnquoted(text.codeUnitAt(pos))) return _string(what);
    _fail('Unexpected "$char", expected $what');
  }

  PbxDict _dict() {
    final start = pos++;
    final entries = <PbxDictEntry>[];
    while (true) {
      _skip();
      if (pos >= text.length) {
        _fail('Unterminated dictionary opened here', start);
      }
      if (_at('}')) {
        pos++;
        return PbxDict(start, pos, entries);
      }
      if (text[pos] != '"' && !_isUnquoted(text.codeUnitAt(pos))) {
        _fail('Unexpected "${text[pos]}", expected a key or "}"');
      }
      final key = _string('a key');
      _skip();
      if (!_at('=')) _fail('Expected "=" after the key "${key.value}"');
      pos++;
      final value = _value('the value of "${key.value}"');
      _skip();
      if (!_at(';')) {
        _fail(
          'Expected ";" after the value of "${key.value}"',
          value.endWithComment,
        );
      }
      pos++;
      entries.add(PbxDictEntry(key, value, pos));
    }
  }

  PbxArray _array() {
    final start = pos++;
    final items = <PbxArrayItem>[];
    while (true) {
      _skip();
      if (pos >= text.length) _fail('Unterminated array opened here', start);
      if (_at(')')) {
        pos++;
        return PbxArray(start, pos, items);
      }
      final value = _value('an array element or ")"');
      _skip();
      if (_at(',')) {
        pos++;
        items.add(PbxArrayItem(value, pos));
      } else if (_at(')')) {
        items.add(PbxArrayItem(value, value.endWithComment));
      } else {
        _fail(
          'Expected "," or ")" after an array element',
          value.endWithComment,
        );
      }
    }
  }

  PbxData _data() {
    final start = pos;
    final close = text.indexOf('>', pos);
    if (close == -1) _fail('Unterminated data value', start);
    pos = close + 1;
    return PbxData(start, pos);
  }

  PbxString _string(String what) {
    final start = pos;
    final String value;
    if (_at('"')) {
      value = _quotedBody(start);
    } else {
      while (pos < text.length &&
          _isUnquoted(text.codeUnitAt(pos)) &&
          !text.startsWith('/*', pos)) {
        pos++;
      }
      if (pos == start) _fail('Expected $what');
      value = text.substring(start, pos);
    }
    final end = pos;
    return PbxString(start, end, value: value, comment: _trailingComment());
  }

  String _quotedBody(int start) {
    pos++;
    final buffer = StringBuffer();
    while (pos < text.length) {
      final char = text[pos];
      if (char == '"') {
        pos++;
        return buffer.toString();
      }
      if (char != r'\') {
        buffer.write(char);
        pos++;
        continue;
      }
      if (pos + 1 >= text.length) break;
      final escaped = text[pos + 1];
      pos += 2;
      switch (escaped) {
        case 'n':
          buffer.write('\n');
        case 't':
          buffer.write('\t');
        case 'r':
          buffer.write('\r');
        case 'a':
          buffer.write('\x07');
        case 'b':
          buffer.write('\b');
        case 'f':
          buffer.write('\f');
        case 'v':
          buffer.write('\v');
        case 'U':
          final hex = RegExp('[0-9A-Fa-f]{1,4}').matchAsPrefix(text, pos);
          if (hex == null) _fail(r'Expected hex digits after "\U"');
          buffer.writeCharCode(int.parse(hex.group(0)!, radix: 16));
          pos = hex.end;
        default:
          final octal = RegExp('[0-7]{1,3}').matchAsPrefix(text, pos - 1);
          if (octal != null) {
            buffer.writeCharCode(int.parse(octal.group(0)!, radix: 8));
            pos = octal.end;
          } else {
            buffer.write(escaped);
          }
      }
    }
    _fail('Unterminated string opened here', start);
  }

  static const String _unquotedPunctuation = r'_$+/:.-';

  static bool _isUnquoted(int char) =>
      (char >= 0x30 && char <= 0x39) ||
      (char >= 0x41 && char <= 0x5A) ||
      (char >= 0x61 && char <= 0x7A) ||
      _unquotedPunctuation.codeUnits.contains(char);
}
