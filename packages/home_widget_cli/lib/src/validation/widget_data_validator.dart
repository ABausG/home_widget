import 'package:home_widget_generator/home_widget_generator.dart';

import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../util/naming.dart';

part 'dart_keywords.dart';
part 'kotlin_keywords.dart';
part 'swift_keywords.dart';

/// ASCII identifier shape safe for codegen across Dart, Kotlin, and Swift.
///
/// Alphanumeric camel-case style keys only (no underscores) so names map cleanly onto
/// generated APIs (Dart named parameters, Kotlin/Swift accessors).
final RegExp asciiDataNamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9]*$');

/// Placeholder syntaxes that a per-locale map cannot express.
///
/// Which plural form or substitution applies depends on runtime data, so these
/// have to be formatted app-side and pushed through a plain [HWString].
final RegExp _placeholderPattern = RegExp(r'\{[A-Za-z0-9_]+\}|%[sdf@]|%\d+\$');

/// Data name reserved for the generated timed data parameter / storage key.
const String reservedTimedDataName = 'timedData';

/// Validates primitive / JSON identifiers and JSON path consistency before codegen.
void validateWidgetData(WidgetSpec spec) {
  // `timedData` only collides with generated API surface when the spec
  // actually has time-based fields (the `saveData(timedData: ...)` parameter,
  // the `deleteData(timedData: ...)` flag and the `.timedData` storage key are
  // only emitted then). Specs without timed fields may use the name freely.
  final reservesTimedDataName = spec.timedDataFields.isNotEmpty;

  for (final field in spec.dataFields) {
    _validateDataTypeKeys(field);
    if (reservesTimedDataName && field.key == reservedTimedDataName) {
      throw GeneratorError(
        'Invalid data name "$reservedTimedDataName" '
        '(${_describeLeafContext(field)}): '
        'reserved for the generated timed data parameter.',
      );
    }
  }

  _validateNoConflictingKeys(spec);
  validateLocalization(spec);
  _validateConditionalData(spec);
  _validateTimedDataKeys(spec);

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
  // Constant localized strings are inlined and never named in generated APIs,
  // so they deliberately carry an empty key.
  if (type is HWLocalizedString && type.isConstant) return;

  if (type is HWTimedData<dynamic>) {
    _validateDataTypeKeys(type.data);
    return;
  }
  _validateAsciiIdentifier(type.key, descriptor: _describeLeafContext(type));
  if (type is HWJson) {
    _validateDataTypeKeys(type.child);
  }
}

/// Rejects conditionals whose branch can never be taken.
///
/// Only [HWDataExists] is null-check shaped. [HWBoolConditional] rejects
/// anything that is not an `HWBool` (or an `HWJson` wrapping one) while
/// decoding, so a localized string can never reach it.
void _validateConditionalData(WidgetSpec spec) {
  for (final widget in _walkWidgets(spec.effectiveWidgetTree)) {
    if (widget is! HWDataExists) continue;
    final data = widget.data;
    if (data is! HWLocalizedString) continue;

    final descriptor = data.isConstant
        ? 'HWText.localized'
        : 'HWString.localized("${data.key}")';
    throw GeneratorError(
      'Widget "${spec.data.name}": HWDataExists cannot test $descriptor. '
      'A localized string always has a value — its compiled default — so the '
      'check is always true and the whenAbsent branch is never rendered. Use a '
      'plain HWString if you want to switch on whether a value is present.',
    );
  }
}

/// Depth-first walk over a widget tree, including the root.
Iterable<HWWidget> _walkWidgets(HWWidget widget) sync* {
  yield widget;
  if (widget is HWSingleChildWidget) {
    yield* _walkWidgets(widget.child);
  } else if (widget is HWMultiChildWidget) {
    for (final child in widget.children) {
      yield* _walkWidgets(child);
    }
  } else if (widget is HWConditional) {
    yield* _walkWidgets(widget.firstBranch);
    yield* _walkWidgets(widget.secondBranch);
  } else if (widget is HWAdaptive) {
    yield* _walkWidgets(widget.ios);
    yield* _walkWidgets(widget.android);
  }
}

/// Validates locale maps, the localization block, and their interaction.
void validateLocalization(WidgetSpec spec) {
  final localized = spec.allLocalizedStrings;
  final localization = spec.data.localization;
  final hasGalleryTranslations = spec.hasLocalizedGalleryStrings;

  if (localized.isEmpty && !hasGalleryTranslations) return;

  if (localization == null) {
    throw GeneratorError(
      'Widget "${spec.data.name}" uses localized strings but has no '
      'localization: HomeWidgetLocalization(...). It supplies the default '
      'locale that every fallback resolves to, and the locale set the '
      'generated Dart localizations class is built from.',
    );
  }

  final supported = localization.supportedLocales;
  if (supported.isEmpty) {
    throw GeneratorError(
      'Widget "${spec.data.name}": supportedLocales must not be empty.',
    );
  }
  if (!supported.contains(localization.defaultLocale)) {
    throw GeneratorError(
      'Widget "${spec.data.name}": defaultLocale '
      '"${localization.defaultLocale}" is not in supportedLocales '
      '(${supported.join(', ')}).',
    );
  }

  final identifiers = <String, String>{};
  for (final locale in supported) {
    if (!isWellFormedLocaleTag(locale)) {
      throw GeneratorError(
        'Widget "${spec.data.name}": "$locale" is not a supported locale tag. '
        'Use language[-Script][-REGION], e.g. "de", "pt-BR" or "zh-Hant". '
        'BCP-47 variants and extensions are not supported.',
      );
    }

    final identifier = localeIdentifier(locale);
    final clash = identifiers[identifier];
    if (clash != null) {
      throw GeneratorError(
        'Widget "${spec.data.name}": locales "$clash" and "$locale" both map to '
        'the Dart identifier "$identifier".',
      );
    }
    identifiers[identifier] = locale;
  }

  // Body strings carry no separate base field, so their map must be complete.
  for (final field in localized) {
    final descriptor = field.isConstant
        ? 'HWText.localized in "${spec.data.name}"'
        : 'HWString.localized("${field.key}")';
    _validateLocaleMap(
      field.defaultTranslations,
      supported: supported,
      descriptor: descriptor,
      requireDefaultLocale: true,
      defaultLocale: localization.defaultLocale,
    );
  }

  _validateGalleryString(
    localization.name,
    baseText: spec.galleryName,
    supported: supported,
    descriptor: 'localization.name',
    baseParameter: 'name',
    defaultLocale: localization.defaultLocale,
  );
  _validateGalleryString(
    localization.description,
    baseText: spec.galleryDescription,
    supported: supported,
    descriptor: 'localization.description',
    baseParameter: 'description',
    defaultLocale: localization.defaultLocale,
  );
}

void _validateGalleryString(
  Map<String, String>? values, {
  required String? baseText,
  required List<String> supported,
  required String descriptor,
  required String baseParameter,
  required String defaultLocale,
}) {
  if (values != null && (baseText == null || baseText.isEmpty)) {
    throw GeneratorError(
      '$descriptor: no default-locale text. Add a "$defaultLocale" entry, or '
      'set the top-level $baseParameter. Without either there is nothing to '
      'show in the widget gallery outside the translated locales.',
    );
  }

  _validateLocaleMap(
    values,
    supported: supported,
    descriptor: descriptor,
    requireDefaultLocale: false,
    defaultLocale: defaultLocale,
  );
}

void _validateLocaleMap(
  Map<String, String>? values, {
  required List<String> supported,
  required String descriptor,
  required bool requireDefaultLocale,
  required String defaultLocale,
}) {
  // Omission means "intentionally not translated" and is always allowed; a map
  // that is present has to be complete, so a forgotten locale is not silent.
  if (values == null) return;

  if (values.isEmpty) {
    throw GeneratorError(
      '$descriptor: locale map is empty. Omit it entirely to leave the string '
      'untranslated.',
    );
  }

  final expected = requireDefaultLocale
      ? supported
      : supported.where((l) => l != defaultLocale).toList();

  for (final locale in values.keys) {
    if (!supported.contains(locale)) {
      throw GeneratorError(
        '$descriptor: locale "$locale" is not in supportedLocales '
        '(${supported.join(', ')}).',
      );
    }
  }

  final missing = expected.where((l) => !values.containsKey(l)).toList();
  if (missing.isNotEmpty) {
    throw GeneratorError(
      '$descriptor: missing translations for ${missing.join(', ')}. Repeat the '
      'base text explicitly if the string is the same in those locales.',
    );
  }

  for (final entry in values.entries) {
    if (_placeholderPattern.hasMatch(entry.value)) {
      throw GeneratorError(
        '$descriptor: "${entry.value}" contains a placeholder. Which plural '
        'form or substitution applies depends on runtime data, so format the '
        'string in your app and push it through a plain HWString instead.',
      );
    }
  }
}

/// Two data fields sharing a key but not their type or shape would emit two
/// identically named properties on the generated data class, which will not
/// compile. JSON leaf keys live in their own nested class per root key and are
/// checked by the path trie instead.
void _validateNoConflictingKeys(WidgetSpec spec) {
  final seen = <String, HWDataType<dynamic>>{};
  for (final field in spec.dataFields) {
    if (field is HWLocalizedString && field.isConstant) continue;

    final existing = seen[field.key];
    if (existing == null) {
      seen[field.key] = field;
      continue;
    }
    if (existing == field) continue;
    if (existing is HWJson && field is HWJson) continue;

    if (existing is HWLocalizedString && field is HWLocalizedString) {
      throw GeneratorError(
        'Widget "${spec.data.name}": two HWString.localized("${field.key}") '
        'entries declare different translations. Give them distinct keys.',
      );
    }
    throw GeneratorError(
      'Widget "${spec.data.name}": the key "${field.key}" is declared as '
      '${_describeDataField(existing)} and ${_describeDataField(field)}. '
      'Both would generate the same field, so give them distinct keys.',
    );
  }
}

String _describeDataField(HWDataType<dynamic> field) {
  if (field is HWLocalizedString) return 'HWString.localized';
  if (field is HWJson) return 'HWJson';
  final defaultValue = field.defaultValue;
  if (defaultValue == null) return '${field.runtimeType}';
  return '${field.runtimeType}(defaultValue: $defaultValue)';
}

/// Rejects keys that are declared both time-based and regular, because both
/// would map onto the same storage key and the same generated parameter name.
void _validateTimedDataKeys(WidgetSpec spec) {
  final timedKeys = <String>{
    for (final field in spec.timedDataFields) field.key,
  };
  if (timedKeys.isEmpty) return;

  for (final field in spec.dataFields) {
    if (field is HWTimedData) continue;
    if (timedKeys.contains(field.key)) {
      throw GeneratorError(
        'Conflicting data name "${field.key}": declared both as time-based '
        '(HWTimedData) and as regular data. Use a different name for one '
        'of them.',
      );
    }
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
