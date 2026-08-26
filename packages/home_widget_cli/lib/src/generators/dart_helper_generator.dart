import 'package:dart_style/dart_style.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';
import '../models/widget_spec.dart';
import '../util/naming.dart';

/// Generates a Dart helper class with type-safe accessors for widget data.
class DartHelperGenerator {
  /// The widget specification to generate helpers for.
  final WidgetSpec spec;

  /// Creates a new [DartHelperGenerator] for the given [spec].
  DartHelperGenerator(this.spec);

  /// Generates the Dart helper source code.
  String generate() {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final hasDataFields = primitiveFields.isNotEmpty || jsonGroups.isNotEmpty;
    final appGroupId = spec.data.iOS?.groupId;
    final usesAppGroupId = hasDataFields && appGroupId != null;

    final buffer = StringBuffer();
    buffer.writeln('// dart format off');
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();
    // Localized fields store their translations as a single JSON blob, so they
    // need `dart:convert` too — but none of the file plumbing JSON groups use.
    if (jsonGroups.isNotEmpty || _localizedFields.isNotEmpty) {
      buffer.writeln("import 'dart:convert';");
    }
    if (jsonGroups.isNotEmpty) {
      buffer.writeln("import 'dart:io';");
      buffer.writeln("import 'dart:typed_data';");
    }
    buffer.writeln("import 'package:home_widget/home_widget.dart';");
    buffer.writeln();

    final className = '${spec.className}HomeWidget';

    buffer.writeln('class $className {');
    buffer.writeln('  const $className._();');
    buffer.writeln();

    if (hasDataFields) {
      if (usesAppGroupId) {
        buffer.writeln("  static const String _\$appGroupId = '$appGroupId';");
        buffer.writeln();
      }
      buffer.writeln(
        "  static const String _\$paramPrefix = 'home_widget.${spec.className}';",
      );
      buffer.writeln();
      for (final field in _localizedFields) {
        _writeDefaultsConstant(buffer, field);
        buffer.writeln();
      }
      buffer.writeln('  static Future<void> saveData({');
      for (final field in primitiveFields) {
        final type = field is HWLocalizedString
            ? _translationsClassName
            : field.dartType;
        buffer.writeln('    $type? ${field.key},');
      }
      for (final group in jsonGroups) {
        final jsonClass = _dartJsonClassName(group.key);
        buffer.writeln('    $jsonClass? ${group.key},');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in primitiveFields) {
        if (field is HWLocalizedString) {
          // Every translation lands in one entry, so a save is atomic from the
          // widget's point of view: it never observes a half-updated set.
          buffer.writeln(
            "      if (${field.key} != null) HomeWidget.saveWidgetData<String>('"
            r"${_$paramPrefix}."
            "${field.key}', jsonEncode(${field.key}.toMap())"
            "${_appGroupIdArg(usesAppGroupId)}),",
          );
          continue;
        }
        final type = field.dartType;
        buffer.writeln(
          "      if (${field.key} != null) HomeWidget.saveWidgetData<$type>('"
          r"${_$paramPrefix}."
          "${field.key}', ${field.key}${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      for (final group in jsonGroups) {
        buffer.writeln('      if (${group.key} != null) () async {');
        buffer.writeln(
          "        await HomeWidget.saveFile('"
          r"${_$paramPrefix}."
          "${group.key}', Uint8List.fromList(utf8.encode(jsonEncode(${group.key}.toJson()))), extension: 'json'${_appGroupIdArg(usesAppGroupId)});",
        );
        buffer.writeln('      }(),');
      }
      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln();

      buffer.writeln('  static Future<void> deleteData({');
      for (final field in primitiveFields) {
        buffer.writeln('    bool ${field.key} = false,');
      }
      for (final group in jsonGroups) {
        buffer.writeln('    bool ${group.key} = false,');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in primitiveFields) {
        // Localized fields need no special case: their translations live in a
        // single entry, so clearing that key clears all of them.
        buffer.writeln(
          "      if (${field.key}) HomeWidget.saveWidgetData('"
          r"${_$paramPrefix}."
          "${field.key}', null${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      for (final group in jsonGroups) {
        buffer.writeln(
          "      if (${group.key}) HomeWidget.saveWidgetData('"
          r"${_$paramPrefix}."
          "${group.key}', null${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      buffer.writeln('    ]);');
      buffer.writeln('  }');
      buffer.writeln();

      final recordFieldParts = <String>[
        ...primitiveFields.map(
          (f) => f is HWLocalizedString
              ? '$_translationsClassName ${f.key}'
              : '${f.dartType}? ${f.key}',
        ),
        ...jsonGroups.map((g) => '${_dartJsonClassName(g.key)}? ${g.key}'),
      ];
      final recordFields = recordFieldParts.join(', ');
      if (_localizedFields.isNotEmpty) {
        buffer.writeln('  /// Reads every stored value back.');
        buffer.writeln('  ///');
        buffer.writeln(
          '  /// Localized fields come back fully populated: anything stored '
          'by [saveData]',
        );
        buffer.writeln(
          '  /// is merged over the compiled defaults, so every locale always '
          'has text.',
        );
        buffer.writeln(
          '  /// To read the raw stored blob instead — to tell an override '
          'apart from a',
        );
        buffer.writeln(
          '  /// shipped default — use `HomeWidget.getWidgetData` on the '
          'preferences key.',
        );
      }
      buffer.writeln(
        '  static Future<({$recordFields})> getData() async {',
      );
      for (final group in jsonGroups) {
        final jsonClass = _dartJsonClassName(group.key);
        buffer.writeln(
          "    final _${group.key}Path = await HomeWidget.getWidgetData<String>('"
          r"${_$paramPrefix}."
          "${group.key}'${_appGroupIdArg(usesAppGroupId)});",
        );
        buffer.writeln('    $jsonClass? ${group.key};');
        buffer.writeln('    if (_${group.key}Path != null) {');
        buffer.writeln('      try {');
        buffer.writeln(
          '        final raw = await File(_${group.key}Path).readAsString();',
        );
        buffer.writeln(
          '        final decoded = jsonDecode(raw);',
        );
        buffer.writeln(
          '        if (decoded is Map<String, dynamic>) ${group.key} = $jsonClass.fromJson(decoded);',
        );
        buffer.writeln('      } on Exception {');
        buffer.writeln('        ${group.key} = null;');
        buffer.writeln('      }');
        buffer.writeln('    }');
      }
      buffer.writeln('    return (');
      for (final field in primitiveFields) {
        if (field is HWLocalizedString) {
          buffer.writeln(
            "      ${field.key}: _\$mergeTranslations(${_defaultsFieldName(field)}, "
            "await _\$readLocalized('"
            r"${_$paramPrefix}."
            "${field.key}')),",
          );
          continue;
        }
        final type = field.dartType;
        final defaultValue = field.defaultValue;
        var defaultLiteral = '';
        if (defaultValue != null) {
          defaultLiteral = defaultValue is String
              ? ", defaultValue: '${escapeDartStringLiteral(defaultValue)}'"
              : ', defaultValue: $defaultValue';
        }
        buffer.writeln(
          "      ${field.key}: await HomeWidget.getWidgetData<$type>('"
          r"${_$paramPrefix}."
          "${field.key}'$defaultLiteral${_appGroupIdArg(usesAppGroupId)}),",
        );
      }
      for (final group in jsonGroups) {
        buffer.writeln('      ${group.key}: ${group.key},');
      }
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln();
    buffer.writeln('  static Future<bool?> updateWidget() {');

    String? androidName;
    final receiverName = '${spec.className}HomeWidgetReceiver';
    if (spec.data.android != null && spec.data.android!.packageName != null) {
      androidName = '${spec.data.android!.packageName}.$receiverName';
    } else {
      androidName = receiverName;
    }

    final iosName =
        spec.data.iOS != null ? '${spec.className}HomeWidget' : null;

    buffer.writeln('    return HomeWidget.updateWidget(');
    buffer.writeln("      androidName: '$androidName',");
    if (iosName != null) {
      buffer.writeln("      iOSName: '$iosName',");
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    if (_localizedFields.isNotEmpty) {
      buffer.writeln();
      _writeLocalizedReader(buffer, usesAppGroupId);
      buffer.writeln();
      _writeTranslationsMerger(buffer);
    }

    buffer.writeln('}');

    if (_localizedFields.isNotEmpty) {
      buffer.writeln();
      _writeTranslationsClass(buffer);
    }

    for (final group in jsonGroups) {
      final jsonClass = _dartJsonClassName(group.key);
      final tree = _buildJsonTree(group.children);
      buffer.writeln();
      _writeDartJsonNodeClass(
        buffer: buffer,
        className: jsonClass,
        node: tree,
        isRoot: true,
      );
    }
    if (jsonGroups.isNotEmpty) {
      buffer.writeln();
      _writeDartJsonReaders(buffer);
    }

    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(buffer.toString());
  }

  /// Keyed localized strings, stored as one JSON blob of locale tag to text.
  ///
  /// Shared with the native generators so the Dart API cannot drift from the
  /// keys they read.
  List<HWLocalizedString> get _localizedFields => spec.keyedLocalizedStrings;

  List<String> get _supportedLocales =>
      spec.data.localization?.supportedLocales ?? const <String>[];

  String get _translationsClassName =>
      '${spec.className}HomeWidgetTranslations';

  /// The identifier of the field holding [field]'s compiled translations.
  ///
  /// One per keyed string rather than a single `defaults`: a widget may declare
  /// several localized fields, each with its own map.
  String _defaultsFieldName(HWLocalizedString field) => '${field.key}Defaults';

  /// The compiled translations for one keyed string, exposed so callers can
  /// read the shipped text without going through `getData`.
  ///
  /// Lives on the helper class rather than on the translations class: that is
  /// where `saveData`/`getData` already are, so the shipped values show up in
  /// completion right next to the calls that override and read them, and one
  /// widget can carry several of these without the shared translations class
  /// having to name them.
  void _writeDefaultsConstant(StringBuffer buffer, HWLocalizedString field) {
    buffer.writeln(
      '  /// The translations compiled into the widget for `${field.key}`.',
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// `getData` merges anything stored by `saveData` over these, so a',
    );
    buffer.writeln(
      '  /// locale the app never pushed still resolves to shipped text.',
    );
    buffer.writeln(
      '  static const $_translationsClassName ${_defaultsFieldName(field)} =',
    );
    buffer.writeln('      $_translationsClassName(');
    for (final locale in _supportedLocales) {
      final value = field.defaultTranslations[locale] ?? '';
      buffer.writeln(
        '        ${localeIdentifier(locale)}: '
        "'${escapeDartStringLiteral(value)}',",
      );
    }
    buffer.writeln('      );');
  }

  /// Merges a stored translation blob over the compiled defaults.
  ///
  /// The defaults are validator-guaranteed to cover every supported locale, so
  /// every required field is satisfied whatever the blob turned out to hold —
  /// the result is total and non-null.
  void _writeTranslationsMerger(StringBuffer buffer) {
    buffer.writeln(
      '  static $_translationsClassName _\$mergeTranslations(',
    );
    buffer.writeln('    $_translationsClassName defaults,');
    buffer.writeln('    Map<String, String>? stored,');
    buffer.writeln('  ) {');
    buffer.writeln('    if (stored == null) return defaults;');
    buffer.writeln('    return $_translationsClassName(');
    for (final locale in _supportedLocales) {
      final identifier = localeIdentifier(locale);
      buffer.writeln(
        "      $identifier: stored['${escapeDartStringLiteral(locale)}'] "
        '?? defaults.$identifier,',
      );
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  /// Reads the stored translation blob for [key] back into a map.
  ///
  /// Returns a raw map rather than [_translationsClassName]: a partial read
  /// cannot satisfy that type's required fields on its own. `getData` closes
  /// the gap by merging the result over the compiled defaults.
  ///
  /// Mirrors the leniency of the native readers — anything that is not a JSON
  /// object of strings reads back as null instead of throwing.
  void _writeLocalizedReader(StringBuffer buffer, bool usesAppGroupId) {
    buffer.writeln(
      '  static Future<Map<String, String>?> _\$readLocalized(String key) async {',
    );
    buffer.writeln(
      "    final raw = await HomeWidget.getWidgetData<String>(key"
      '${_appGroupIdArg(usesAppGroupId)});',
    );
    buffer.writeln('    if (raw == null) return null;');
    buffer.writeln('    Object? decoded;');
    buffer.writeln('    try {');
    buffer.writeln('      decoded = jsonDecode(raw);');
    buffer.writeln('    } on FormatException {');
    buffer.writeln('      return null;');
    buffer.writeln('    }');
    buffer.writeln('    if (decoded is! Map) return null;');
    buffer.writeln('    final values = <String, String>{};');
    buffer.writeln('    decoded.forEach((locale, value) {');
    buffer.writeln(
      '      if (locale is String && value is String) values[locale] = value;',
    );
    buffer.writeln('    });');
    buffer.writeln('    return values.isEmpty ? null : values;');
    buffer.writeln('  }');
  }

  /// A translation set for one string, with every supported locale required so
  /// that adding a locale becomes a compile error until it is translated.
  void _writeTranslationsClass(StringBuffer buffer) {
    final locales = _supportedLocales;
    buffer.writeln('class $_translationsClassName {');
    buffer.writeln('  const $_translationsClassName({');
    for (final locale in locales) {
      buffer.writeln('    required this.${localeIdentifier(locale)},');
    }
    buffer.writeln('  });');
    buffer.writeln();
    for (final locale in locales) {
      buffer.writeln('  final String ${localeIdentifier(locale)};');
    }
    buffer.writeln();
    buffer.writeln('  Map<String, String> toMap() => {');
    for (final locale in locales) {
      buffer.writeln("        '$locale': ${localeIdentifier(locale)},");
    }
    buffer.writeln('      };');
    buffer.writeln();
    _writeResolve(buffer);
    buffer.writeln('}');
  }

  /// `resolve(tag)` — the widget's own matching chain, for one explicit tag.
  ///
  /// Mirrors `hwResolveLocalized` in the Kotlin and Swift helpers step for
  /// step, including the lexicographically smallest region/script sibling, so
  /// a preview cannot disagree with what the widget renders.
  ///
  /// Matching is case-insensitive: BCP-47 tags are case-insensitive by spec,
  /// and the native resolvers only ever see canonically cased tags, so folding
  /// case here can never conflate two genuinely different tags.
  void _writeResolve(StringBuffer buffer) {
    final baseIdentifier = _baseLocaleIdentifier;
    buffer.writeln(
      '  /// The text this set resolves to for the BCP-47 locale [tag].',
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// Tries the exact tag (`pt-PT`), then the bare language (`pt`),',
    );
    buffer.writeln(
      '  /// then any entry with the same language but a different region or',
    );
    buffer.writeln(
      '  /// script (`pt-BR`; the lexicographically smallest wins if several',
    );
    buffer.writeln(
      "  /// match), and finally the widget's default locale. Matching is",
    );
    buffer.writeln(
      '  /// case-insensitive, and `_` is treated as `-`.',
    );
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// The widget natively runs these same steps against *every* entry',
    );
    buffer.writeln(
      "  /// of the OS preferred-language list in order; this answers for one",
    );
    buffer.writeln(
      '  /// explicit tag, which is what previews and tests need.',
    );
    buffer.writeln('  String resolve(String tag) {');
    // Tags are case-insensitive per BCP-47, so both sides fold to lower case.
    buffer.writeln('    final values = {');
    buffer.writeln('      for (final entry in toMap().entries)');
    buffer.writeln('        entry.key.toLowerCase(): entry.value,');
    buffer.writeln('    };');
    buffer.writeln(
      "    final normalized = tag.replaceAll('_', '-').toLowerCase();",
    );
    if (baseIdentifier == null) {
      buffer.writeln("    return values[normalized] ?? '';");
      buffer.writeln('  }');
      return;
    }
    buffer.writeln('    final exact = values[normalized];');
    buffer.writeln('    if (exact != null) return exact;');
    buffer.writeln("    final language = normalized.split('-').first;");
    buffer.writeln('    final byLanguage = values[language];');
    buffer.writeln('    if (byLanguage != null) return byLanguage;');
    buffer.writeln('    String? sibling;');
    buffer.writeln('    for (final key in values.keys) {');
    buffer.writeln("      if (key.split('-').first != language) continue;");
    buffer.writeln(
      '      if (sibling == null || key.compareTo(sibling) < 0) sibling = key;',
    );
    buffer.writeln('    }');
    buffer.writeln('    if (sibling != null) {');
    buffer.writeln('      final match = values[sibling];');
    buffer.writeln('      if (match != null) return match;');
    buffer.writeln('    }');
    buffer.writeln('    return $baseIdentifier;');
    buffer.writeln('  }');
  }

  /// The field holding the widget's default-locale text, or null when there is
  /// no usable default locale (only reachable for specs validation rejects).
  String? get _baseLocaleIdentifier {
    final locales = _supportedLocales;
    if (locales.isEmpty) return null;
    final defaultLocale = spec.data.localization?.defaultLocale;
    if (defaultLocale != null && locales.contains(defaultLocale)) {
      return localeIdentifier(defaultLocale);
    }
    return localeIdentifier(locales.first);
  }

  String _appGroupIdArg(bool usesAppGroupId) =>
      usesAppGroupId ? r', appGroupId: _$appGroupId' : '';

  String _dartJsonClassName(String key) => '${toPascalCase(key)}JsonData';

  _JsonPathNode _buildJsonTree(List<JsonDataField> fields) {
    final root = _JsonPathNode();
    for (final field in fields) {
      var node = root;
      for (final segment in field.path) {
        node = node.children.putIfAbsent(segment, _JsonPathNode.new);
      }
      node.leafType = field.type;
    }
    return root;
  }

  void _writeDartJsonNodeClass({
    required StringBuffer buffer,
    required String className,
    required _JsonPathNode node,
    required bool isRoot,
  }) {
    buffer.writeln('class $className {');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        buffer.writeln('  final ${child.leafType!.dartType}? $key;');
      } else {
        final childClass = _dartChildClassName(className, key);
        buffer.writeln('  final $childClass? $key;');
      }
    }
    buffer.writeln();
    buffer.writeln('  const $className({');
    for (final key in node.children.keys) {
      buffer.writeln('    this.$key,');
    }
    buffer.writeln('  });');
    buffer.writeln();
    buffer
        .writeln('  factory $className.fromJson(Map<String, dynamic>? json) {');
    buffer.writeln('    json ??= const {};');
    buffer.writeln('    return $className(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final fallback = _dartDefaultLiteral(child.leafType!);
        buffer.writeln(
          "      $key: ${_dartReadFunction(child.leafType!)}(json['$key'])$fallback,",
        );
      } else {
        final childClass = _dartChildClassName(className, key);
        buffer.writeln(
          "      $key: json['$key'] is Map<String, dynamic> ? $childClass.fromJson(json['$key'] as Map<String, dynamic>) : null,",
        );
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        buffer.writeln("      if ($key != null) '$key': $key,");
      } else {
        buffer.writeln("      if ($key != null) '$key': $key!.toJson(),");
      }
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');

    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.children.isNotEmpty || child.leafType == null) {
        buffer.writeln();
        final childClass = _dartChildClassName(className, key);
        _writeDartJsonNodeClass(
          buffer: buffer,
          className: childClass,
          node: child,
          isRoot: false,
        );
      }
    }
  }

  void _writeDartJsonReaders(StringBuffer buffer) {
    buffer.writeln(
      'String? _readString(Object? value) => value is String ? value : null;',
    );
    buffer.writeln(
      'int? _readInt(Object? value) => value is num ? value.toInt() : null;',
    );
    buffer.writeln(
      'double? _readDouble(Object? value) => value is num ? value.toDouble() : null;',
    );
    buffer.writeln(
      'bool? _readBool(Object? value) => value is bool ? value : null;',
    );
  }

  String _dartReadFunction(HWDataType<dynamic> field) {
    if (field is HWString) return '_readString';
    if (field is HWInt) return '_readInt';
    if (field is HWDouble) return '_readDouble';
    if (field is HWBool) return '_readBool';
    return '_readString';
  }

  String _dartChildClassName(String parentClass, String key) {
    final base = parentClass.endsWith('JsonData')
        ? parentClass.substring(0, parentClass.length - 'JsonData'.length)
        : parentClass;
    return '$base${toPascalCase(key)}JsonData';
  }

  String _dartDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return '';
    if (defaultValue is String) {
      return " ?? '${escapeDartStringLiteral(defaultValue)}'";
    }
    return ' ?? $defaultValue';
  }
}

class _JsonPathNode {
  final Map<String, _JsonPathNode> children = {};
  HWDataType<dynamic>? leafType;
}
