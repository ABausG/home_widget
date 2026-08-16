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

/// Validates primitive / JSON identifiers and JSON path consistency before codegen.
void validateWidgetData(WidgetSpec spec) {
  for (final field in spec.dataFields) {
    _validateDataTypeKeys(field);
  }

  validateLocalization(spec);

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

  _validateAsciiIdentifier(type.key, descriptor: _describeLeafContext(type));
  if (type is HWJson) {
    if (_containsLocalized(type.child)) {
      throw GeneratorError(
        'Localized strings cannot be nested inside HWJson (in "${type.key}"). '
        'JSON values come from the app at runtime, so translate them there and '
        'pass the result through a plain HWString.',
      );
    }
    _validateDataTypeKeys(type.child);
  }
}

bool _containsLocalized(HWDataType<dynamic> type) {
  if (type is HWLocalizedString) return true;
  if (type is HWJson) return _containsLocalized(type.child);
  return false;
}

/// Validates locale maps, the localization block, and their interaction.
void validateLocalization(WidgetSpec spec) {
  final localized = spec.localizedStrings;
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
      field.defaultValues,
      supported: supported,
      descriptor: descriptor,
      requireDefaultLocale: true,
      defaultLocale: localization.defaultLocale,
    );
  }

  // Gallery strings take their base value from the top-level name/description,
  // so including the default locale here would be a second source of truth.
  _validateLocaleMap(
    localization.name,
    supported: supported,
    descriptor: 'localization.name',
    requireDefaultLocale: false,
    defaultLocale: localization.defaultLocale,
  );
  _validateLocaleMap(
    localization.description,
    supported: supported,
    descriptor: 'localization.description',
    requireDefaultLocale: false,
    defaultLocale: localization.defaultLocale,
  );

  _validateNoConflictingKeys(spec);
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
    if (!requireDefaultLocale && locale == defaultLocale) {
      throw GeneratorError(
        '$descriptor: remove "$defaultLocale". The default-locale text is the '
        'top-level name/description; having it here too would be a second '
        'source of truth.',
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

/// Two localized strings sharing a key but not their translations would emit
/// two identically named fields, which will not compile.
void _validateNoConflictingKeys(WidgetSpec spec) {
  final seen = <String, HWLocalizedString>{};
  for (final field in spec.keyedLocalizedStrings) {
    final existing = seen[field.key];
    if (existing != null && existing != field) {
      throw GeneratorError(
        'Widget "${spec.data.name}": two HWString.localized("${field.key}") '
        'entries declare different translations. Give them distinct keys.',
      );
    }
    seen[field.key] = field;
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
