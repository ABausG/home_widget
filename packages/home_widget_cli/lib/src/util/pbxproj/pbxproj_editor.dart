import 'pbxproj_document.dart';

export 'pbxproj_document.dart';

/// [value] the way Xcode writes it: bare when it can be, quoted and escaped
/// otherwise — `Debug` stays bare, `Debug-dev` becomes `"Debug-dev"`.
String pbxLiteral(String value) {
  if (RegExp(r'^[A-Za-z0-9_$./]+$').hasMatch(value) &&
      !value.contains('//') &&
      !value.contains('___')) {
    return value;
  }
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}

/// Edits a `project.pbxproj` by splicing its text at the offsets a parse
/// reports, so everything an edit does not touch keeps its exact bytes.
///
/// Each edit that changes the text drops the parse; the next read of [project]
/// parses the new text. Inserted line breaks match the file's own.
final class PbxprojEditor {
  /// Creates an editor over [text].
  PbxprojEditor(String text) : this._(text, null);

  /// Creates an editor over the text [project] was parsed from, starting from
  /// that parse.
  PbxprojEditor.parsed(Pbxproj project) : this._(project.text, project);

  PbxprojEditor._(this._text, this._project) : _newline = _lineBreakOf(_text);

  static final RegExp _bareLineFeed = RegExp(r'(?<!\r)\n');

  static String _lineBreakOf(String text) {
    final lineFeed = text.indexOf('\n');
    return lineFeed > 0 && text[lineFeed - 1] == '\r' ? '\r\n' : '\n';
  }

  String _text;
  final String _newline;
  Pbxproj? _project;

  /// The text with every edit so far applied.
  String get text => _text;

  /// [text], parsed.
  Pbxproj get project => _project ??= Pbxproj.parse(_text);

  /// The source of [item] with the comment following it, without the comma.
  String itemText(PbxArrayItem item) =>
      project.text.substring(item.start, item.textEnd);

  /// Inserts [objects], rendered objects of class [isa] given as whole lines,
  /// at the end of the section holding that class.
  ///
  /// A missing section is created where Xcode puts it, sections being sorted
  /// by class name.
  void insertObjects(String isa, String objects) {
    final project = this.project;
    final sections = [
      for (final section in project.sections)
        if (section.end != null) section,
    ];

    final own = sections.where((section) => section.isa == isa).firstOrNull;
    if (own != null) {
      _insertLinesBefore(own.end!.start, objects);
      return;
    }
    final last = project.objectsOfIsa(isa).lastOrNull;
    if (last != null) {
      _insertLinesAfter(last.entry.end, objects);
      return;
    }

    final section = '''
/* Begin $isa section */
$objects/* End $isa section */
''';
    final following =
        sections.where((section) => section.isa.compareTo(isa) > 0).firstOrNull;
    if (following != null) {
      _insertLinesBefore(following.begin.start, '''
$section
''');
    } else if (sections.isNotEmpty) {
      _insertLinesAfter(sections.last.end!.end, '''

$section''');
    } else {
      _insertLinesBefore(project.objectsDict.end - 1, section);
    }
  }

  /// Appends [value], titled [comment], to the array field [field] of
  /// [objectId] unless one of its elements already is [value], creating the
  /// field when the object has none.
  void addArrayEntry(
    String objectId,
    String field,
    String value, {
    String? comment,
  }) {
    final object = project.object(objectId);
    if (object == null) return;
    final literal = comment == null
        ? pbxLiteral(value)
        : '${pbxLiteral(value)} /* $comment */';
    final entry = object.fields.entry(field);
    if (entry == null) {
      _insertEntry(
        object.fields,
        field,
        (indent) => '''
$field = (
$indent\t$literal,
$indent);''',
      );
      return;
    }

    final array = entry.value;
    if (array is! PbxArray || array.strings.contains(value)) return;
    final close = array.end - 1;
    if (_startsLine(close)) {
      final first = array.items.firstOrNull;
      final indent = first != null && _startsLine(first.start)
          ? _indentAt(first.start)
          : '${_indentAt(close)}\t';
      _insert(_lineStart(close), '''
$indent$literal,
''');
    } else {
      _insert(close, '$literal, ');
    }
    final last = array.items.lastOrNull;
    if (last != null && last.end == last.textEnd) {
      _insert(last.textEnd, last.textEnd == close ? ', ' : ',');
    }
  }

  /// Rewrites the elements of the array field [field] of [objectId] to
  /// [literals], in that order.
  void setArrayItems(String objectId, String field, List<String> literals) {
    final array = project.object(objectId)?.fields.array(field);
    if (array == null) return;
    final current = [for (final item in array.items) itemText(item)];
    if (current.length == literals.length &&
        Iterable<int>.generate(current.length)
            .every((i) => current[i] == literals[i])) {
      return;
    }

    final close = array.end - 1;
    if (!_startsLine(close)) {
      _replace(
        array.start,
        array.end,
        '(${literals.map((literal) => '$literal, ').join()})',
      );
      return;
    }
    final closeIndent = _indentAt(close);
    final first = array.items.firstOrNull;
    final indent = first != null && _startsLine(first.start)
        ? _indentAt(first.start)
        : '$closeIndent\t';
    final buffer = StringBuffer()..writeln('(');
    for (final literal in literals) {
      buffer.writeln('$indent$literal,');
    }
    buffer.write('$closeIndent)');
    _replace(array.start, array.end, buffer.toString());
  }

  /// Sets the build setting [key] of the configuration [configurationId] to
  /// [value], replacing a list value whole and dropping duplicates of [key].
  ///
  /// A new setting goes where Xcode sorts it.
  void setBuildSetting(String configurationId, String key, String value) {
    final configuration = project.object(configurationId);
    if (configuration == null) return;
    final literal = pbxLiteral(value);
    final settings = configuration.fields.dict('buildSettings');
    if (settings == null) {
      _insertEntry(
        configuration.fields,
        'buildSettings',
        (indent) => '''
buildSettings = {
$indent\t${pbxLiteral(key)} = $literal;
$indent};''',
      );
      return;
    }

    final existing = [
      for (final entry in settings.entries)
        if (entry.key.value == key) entry,
    ];
    if (existing.isEmpty) {
      _insertEntry(settings, key, (_) => '${pbxLiteral(key)} = $literal;');
      return;
    }
    final last = existing.removeLast();
    final keyText = _text.substring(last.key.start, last.key.end);
    _replace(last.start, last.end, '$keyText = $literal;');
    for (final duplicate in existing.reversed) {
      _remove(duplicate.start, duplicate.end);
    }
  }

  /// Removes every entry of the build setting [key] of the configuration
  /// [configurationId].
  void removeBuildSetting(String configurationId, String key) {
    final settings =
        project.object(configurationId)?.fields.dict('buildSettings');
    for (final entry in settings?.entries.reversed ?? const <PbxDictEntry>[]) {
      if (entry.key.value == key) _remove(entry.start, entry.end);
    }
  }

  /// Removes the objects [ids], every array element naming one of them, and
  /// the markers of a section left empty.
  void removeObjects(Set<String> ids) {
    final project = this.project;
    final objects = project.objectsDict.entries;
    bool emptied(PbxComment begin, PbxComment end) {
      final inside = objects.where(
        (entry) => entry.start > begin.end && entry.end <= end.start,
      );
      return inside.isNotEmpty &&
          inside.every((entry) => ids.contains(entry.key.value));
    }

    final spans = <(int, int)>[
      for (final entry in objects)
        if (ids.contains(entry.key.value)) (entry.start, entry.end),
      for (final array in project.nodes.whereType<PbxArray>())
        for (final item in array.items)
          if (ids.contains(item.string)) (item.start, item.end),
      for (final PbxSection(:begin, :end) in project.sections)
        if (end != null && emptied(begin, end))
          (_sectionStart(begin.start, end.end), end.end),
    ];
    final outermost = spans
        .where(
          (span) => !spans.any(
            (other) =>
                other != span && other.$1 <= span.$1 && span.$2 <= other.$2,
          ),
        )
        .toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (start, end) in outermost) {
      _remove(start, end);
    }
  }

  /// Rewrites every `/* … */` title following the id [id] to [title].
  void retitle(String id, String title) {
    final comments = [
      for (final string in project.nodes.whereType<PbxString>())
        if (string.value == id && string.comment != null) string.comment!,
    ]..sort((a, b) => b.start.compareTo(a.start));
    for (final comment in comments) {
      _replace(comment.start, comment.end, '/* $title */');
    }
  }

  void _insertEntry(
    PbxDict dict,
    String key,
    String Function(String indent) render,
  ) {
    final isa = dict.entries.indexWhere((entry) => entry.key.value == 'isa');
    final following = dict.entries.skip(isa + 1).where(
          (entry) =>
              entry.key.value.compareTo(key) > 0 && _startsLine(entry.start),
        );
    if (following.isNotEmpty) {
      final start = following.first.start;
      final indent = _indentAt(start);
      _insert(_lineStart(start), '''
$indent${render(indent)}
''');
      return;
    }

    final close = dict.end - 1;
    if (!_startsLine(close)) {
      _insert(close, '${render('')} ');
      return;
    }
    final last = dict.entries.lastOrNull;
    final indent = last != null && _startsLine(last.start)
        ? _indentAt(last.start)
        : '${_indentAt(close)}\t';
    _insert(_lineStart(close), '''
$indent${render(indent)}
''');
  }

  /// Where removing the section whose markers span [begin] to [end] starts:
  /// at the blank line Xcode writes before a section on its own lines.
  int _sectionStart(int begin, int end) {
    if (!_startsLine(begin) || !_endsLine(end)) return begin;
    final lineStart = _lineStart(begin);
    final previous = _lineStart(lineStart - 1);
    return _text.substring(previous, lineStart).trim().isEmpty
        ? previous
        : begin;
  }

  /// Inserts [lines] at the start of the line holding [offset], or on a new
  /// line at [offset] when something precedes it on its line.
  void _insertLinesBefore(int offset, String lines) {
    if (_startsLine(offset)) {
      _insert(_lineStart(offset), lines);
      return;
    }
    var start = offset;
    while (_isBlank(start - 1)) {
      start--;
    }
    _replace(start, offset, '$_newline$lines');
  }

  /// Inserts [lines] at the start of the line after [offset], or on a new
  /// line at [offset] when something follows it on its line.
  void _insertLinesAfter(int offset, String lines) {
    if (_endsLine(offset)) {
      _insert(_nextLineStart(offset), lines);
      return;
    }
    var end = offset;
    while (_isBlank(end)) {
      end++;
    }
    _replace(offset, end, '$_newline$lines');
  }

  void _remove(int start, int end) {
    if (_startsLine(start) && _endsLine(end)) {
      _replace(_lineStart(start), _nextLineStart(end), '');
      return;
    }
    var from = start;
    var to = end;
    while (_isBlank(to)) {
      to++;
    }
    if (_endsLine(to)) {
      while (_isBlank(from - 1)) {
        from--;
      }
    }
    _replace(from, to, '');
  }

  void _insert(int offset, String text) => _replace(offset, offset, text);

  void _replace(int start, int end, String replacement) {
    final text = replacement.replaceAll(_bareLineFeed, _newline);
    if (_text.substring(start, end) == text) return;
    _text = _text.replaceRange(start, end, text);
    _project = null;
  }

  bool _isBlank(int offset) =>
      offset >= 0 &&
      offset < _text.length &&
      (_text[offset] == ' ' || _text[offset] == '\t');

  int _lineStart(int offset) =>
      offset <= 0 ? 0 : _text.lastIndexOf('\n', offset - 1) + 1;

  int _nextLineStart(int offset) {
    final newline = _text.indexOf('\n', offset);
    return newline == -1 ? _text.length : newline + 1;
  }

  String _indentAt(int offset) =>
      RegExp('[ \t]*').matchAsPrefix(_text, _lineStart(offset))!.group(0)!;

  bool _startsLine(int offset) =>
      _text.substring(_lineStart(offset), offset).trim().isEmpty;

  bool _endsLine(int offset) {
    final newline = _text.indexOf('\n', offset);
    return _text
        .substring(offset, newline == -1 ? _text.length : newline)
        .trim()
        .isEmpty;
  }
}
