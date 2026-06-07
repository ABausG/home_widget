import 'package:home_widget_generator/home_widget_generator.dart';

import '../generator_error.dart';
import '../models/widget_spec.dart';

part 'dart_keywords.dart';
part 'kotlin_keywords.dart';
part 'swift_keywords.dart';

/// ASCII identifier shape safe for codegen across Dart, Kotlin, and Swift.
///
/// Alphanumeric camel-case style keys only (no underscores) so names map cleanly onto
/// generated APIs (Dart named parameters, Kotlin/Swift accessors).
final RegExp asciiDataNamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9]*$');

/// Validates primitive / JSON identifiers and JSON path consistency before codegen.
void validateWidgetData(WidgetSpec spec) {
  for (final field in spec.dataFields) {
    _validateDataTypeKeys(field);
  }

  for (final group in spec.jsonDataGroups) {
    _validateAsciiIdentifier(group.key, descriptor: 'JSON root');
    final root = _TrieNode();
    for (final field in group.children) {
      for (final segment in field.path) {
        _validateAsciiIdentifier(
          segment,
          descriptor: 'JSON path segment in "${group.key}"',
        );
      }
      root.insertField(group.key, path: field.path, field: field);
    }
  }
}

void _validateDataTypeKeys(HWDataType<dynamic> type) {
  _validateAsciiIdentifier(type.key, descriptor: _describeLeafContext(type));
  if (type is HWJson) {
    _validateDataTypeKeys(type.child);
  }
}

String _describeLeafContext(HWDataType<dynamic> type) {
  if (type is HWJson) {
    final path = '${type.key}.${type.pathSegments.join('.')}';
    return 'JSON access $path';
  }
  return 'field "${type.key}"';
}

void _validateAsciiIdentifier(
  String name, {
  required String descriptor,
}) {
  if (name.isEmpty) {
    throw GeneratorError('Invalid data name for $descriptor: name is empty.');
  }
  if (!asciiDataNamePattern.hasMatch(name)) {
    throw GeneratorError(
      'Invalid data name "$name" ($descriptor): '
      'use ASCII letters and digits only; must start with a letter.',
    );
  }

  final lower = name.toLowerCase();
  final platforms = [
    if (_dartKeywords.contains(lower)) 'Dart',
    if (_kotlinKeywords.contains(lower)) 'Kotlin',
    if (_swiftKeywords.contains(lower)) 'Swift',
  ];
  if (platforms.isEmpty) return;

  final where = platforms.length == 1
      ? platforms.single
      : '${platforms.sublist(0, platforms.length - 1).join(', ')} '
          'and ${platforms.last}';

  throw GeneratorError(
    'Invalid data name "$name" ($descriptor): '
    'reserved keyword in $where.',
  );
}

final class _TrieNode {
  final Map<String, _TrieNode> children = {};

  /// Primitive leaf mapped at this node's property (`root.a.[...]`).
  JsonDataField? leafField;

  void insertField(
    String jsonRootKey, {
    required List<String> path,
    required JsonDataField field,
  }) {
    // coverage:ignore-start
    if (path.isEmpty) {
      throw GeneratorError(
        'Invalid JSON leaf in JSON group "$jsonRootKey": '
        'empty path is not supported.',
      );
    }
    // coverage:ignore-end

    var node = this;
    for (var i = 0; i < path.length; i++) {
      final segment = path[i];
      final isLast = i == path.length - 1;
      final slot = node.children.putIfAbsent(segment, _TrieNode.new);

      if (!isLast) {
        if (slot.leafField != null) {
          throw GeneratorError(
            _jsonConflictMessage(
              jsonRootKey,
              reason: 'cannot add nested "${_dotted(path.sublist(0, i + 1))}" '
                  'because "$segment" is already mapped to a primitive leaf '
                  '(${_fieldSummary(slot.leafField!)}). ${_fieldSummaryIncoming(field)}',
            ),
          );
        }
        node = slot;
        continue;
      }

      // Terminal property
      if (slot.children.isNotEmpty) {
        throw GeneratorError(
          _jsonConflictMessage(
            jsonRootKey,
            reason:
                '"${_dotted(path)}" is a primitive leaf but "$segment" already '
                'contains nested JSON. ${_fieldSummaryIncoming(field)}',
          ),
        );
      }
      if (slot.leafField != null) {
        if (_sameJsonLeaf(slot.leafField!, field)) {
          return;
        }
        throw GeneratorError(
          _jsonConflictMessage(
            jsonRootKey,
            reason: 'conflicting leaves at "${_dotted(path)}": '
                '${_fieldSummary(slot.leafField!)} '
                'vs ${_fieldSummary(field)}.',
          ),
        );
      }
      slot.leafField = field;
    }
  }
}

bool _sameJsonLeaf(JsonDataField a, JsonDataField b) =>
    _segmentsEqual(a.path, b.path) &&
    identical(a.type.runtimeType, b.type.runtimeType) &&
    a.type.key == b.type.key &&
    a.type.defaultValue == b.type.defaultValue;

bool _segmentsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _dotted(List<String> segments) =>
    segments.isEmpty ? '<root>' : segments.join('.');

String _fieldSummaryIncoming(JsonDataField field) =>
    'Conflicting declaration: ${_fieldSummary(field)}.';

String _fieldSummary(JsonDataField field) {
  final dv = field.type.defaultValue;
  final dvText = dv == null ? 'no default' : 'default=$dv';
  return '${field.path.join('.')} → '
      '${field.type.runtimeType} (${field.type.key}, $dvText)';
}

String _jsonConflictMessage(String jsonRootKey, {required String reason}) =>
    'Conflicting JSON paths in JSON group "$jsonRootKey": $reason';
