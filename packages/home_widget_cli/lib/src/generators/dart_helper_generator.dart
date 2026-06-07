import 'package:dart_style/dart_style.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
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
    if (jsonGroups.isNotEmpty) {
      buffer.writeln("import 'dart:convert';");
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
      buffer.writeln('  static Future<void> saveData({');
      for (final field in primitiveFields) {
        final type = field.dartType;
        buffer.writeln('    $type? ${field.key},');
      }
      for (final group in jsonGroups) {
        final jsonClass = _dartJsonClassName(group.key);
        buffer.writeln('    $jsonClass? ${group.key},');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return Future.wait([');
      for (final field in primitiveFields) {
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
        ...primitiveFields.map((f) => '${f.dartType}? ${f.key}'),
        ...jsonGroups.map((g) => '${_dartJsonClassName(g.key)}? ${g.key}'),
      ];
      final recordFields = recordFieldParts.join(', ');
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
        final type = field.dartType;
        final defaultValue = field.defaultValue;
        var defaultLiteral = '';
        if (defaultValue != null) {
          defaultLiteral = defaultValue is String
              ? ", defaultValue: '$defaultValue'"
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

    buffer.writeln('}');

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
      final escaped =
          defaultValue.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      return " ?? '$escaped'";
    }
    return ' ?? $defaultValue';
  }
}

class _JsonPathNode {
  final Map<String, _JsonPathNode> children = {};
  HWDataType<dynamic>? leafType;
}
