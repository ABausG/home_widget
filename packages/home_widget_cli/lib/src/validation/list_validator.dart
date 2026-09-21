part of 'widget_data_validator.dart';

/// Validates the lists the builders of [spec] render and the item fields their
/// items read.
///
/// Runs ahead of every other check of [validateWidgetData]: an [HWItemData]
/// outside an item reaches the widget's own data fields, where it would
/// otherwise surface as a misleading key conflict.
void validateLists(WidgetSpec spec) {
  _validateItemReadScope(spec);

  final groups = spec.listDataGroups;
  for (final group in groups) {
    _validateListKey(spec, group);
    _validateListTiming(spec, group);
    _validateItemFields(spec, group);
    _validateItemPreviewDates(spec, group);
  }
  _validateListCollisions(spec, groups);

  for (final group in groups) {
    _warnAboutUnevenPreviewValues(spec, group);
  }
}

/// Rejects an [HWItemData] read anywhere but the item of a builder.
///
/// A builder keeps the item fields its item reads to itself, so one among the
/// widget's own data fields sits where there is no item to read: the root
/// tree, a `whenEmpty`, an [HWDataOnly] outside an item.
void _validateItemReadScope(WidgetSpec spec) {
  for (final field in spec.declaredDataFields) {
    if (field.unwrapped is! HWItemData) continue;
    throw GeneratorError(
      'Widget "${spec.data.name}": ${_spellItemRead(field)} reads the item a '
      'builder is rendering, so it only works inside the item of an '
      'HWColumn.builder or HWRow.builder.',
    );
  }
}

/// [read] the way a schema writes it, e.g. `HWItemData(HWString('label'))`.
String _spellItemRead(HWDataType<dynamic> read) => switch (read) {
      HWTimedData(:final data) => 'HWTimedData(${_spellItemRead(data)})',
      HWItemData(:final data) => 'HWItemData(${_spellItemRead(data)})',
      HWLocalizedString() => "HWString.localized('${read.key}')",
      _ => "${read.runtimeType}('${read.key}')",
    };

/// Rejects a list key the generated API cannot be named after.
void _validateListKey(WidgetSpec spec, ListDataGroup group) {
  final descriptor = 'list "${group.key}"';
  _validateAsciiIdentifier(
    group.key,
    descriptor: descriptor,
    membersClass: true,
  );
  if (group.key == reservedTimedDataName && spec.hasTimedData) {
    throw GeneratorError(
      'Invalid data name "$reservedTimedDataName" ($descriptor): '
      'reserved for the generated timed data parameter.',
    );
  }
}

/// Rejects a list read both time-based and not.
///
/// Every timed entry carries a list of its own, so there is no list outside
/// the entries for an untimed read to take its items from.
void _validateListTiming(WidgetSpec spec, ListDataGroup group) {
  final timed = <String>{};
  final untimed = <String>{};
  for (final declaration in group.declarations) {
    for (final read in declaration.reads) {
      (read is HWTimedData ? timed : untimed).add(read.key);
    }
  }
  if (timed.isEmpty || untimed.isEmpty) return;

  throw GeneratorError(
    'Widget "${spec.data.name}": the list "${group.key}" is read both '
    'time-based (${timed.join(', ')}) and not (${untimed.join(', ')}). A list '
    'is time-based as a whole: wrap every item field of "${group.key}" in '
    'HWTimedData, or none.',
  );
}

/// Rejects an item field key the item class cannot be generated with, and two
/// reads of one item field describing it differently.
///
/// The item fields of a list have a namespace of their own, so one may share
/// its key with a field of the widget's own data.
void _validateItemFields(WidgetSpec spec, ListDataGroup group) {
  final seen = <String, HWItemData<dynamic>>{};
  for (final declaration in group.declarations) {
    for (final read in declaration.reads) {
      final field = read.unwrapped as HWItemData<dynamic>;
      _validateAsciiIdentifier(
        field.key,
        descriptor: 'item field "${field.key}" of list "${group.key}"',
        membersClass: true,
      );

      final existing = seen[field.key];
      if (existing == null) {
        seen[field.key] = field;
        continue;
      }
      // Folded the way `WidgetSpec.listDataGroups` folds them, so a third
      // read is checked against everything set so far.
      if (existing.isCompatibleWith(field)) {
        seen[field.key] = existing.mergedWith(field) as HWItemData<dynamic>;
        continue;
      }
      throw GeneratorError(
        'Widget "${spec.data.name}": conflicting item fields in list '
        '"${group.key}": "${field.key}" is declared as '
        '${_describeItemField(existing)} and as ${_describeItemField(field)}. '
        'Both describe the same member of the item class, so declare them '
        'alike or give them distinct keys.',
      );
    }
  }
}

/// Names the item field [field] the way its declaration reads, down to the
/// values two reads of one item field can disagree on.
String _describeItemField(HWItemData<dynamic> field) {
  final data = field.data;
  final described = switch (data) {
    HWLocalizedString(:final defaultTranslations, :final previewTranslations) =>
      'HWString.localized(defaultTranslations: $defaultTranslations'
          '${previewTranslations == null ? '' : ', previewTranslations: $previewTranslations'})',
    HWIconData(:final entries) => '${_describeDataField(data)} of icons '
        '[${entries.map((entry) => entry.name).join(', ')}]',
    _ => _describeDataField(data),
  };

  final values = field.previewValues;
  if (values == null) return described;
  final entries = values.map((v) => v is String ? '"$v"' : '$v').join(', ');
  return '$described with previewValues [$entries]';
}

/// Rejects a preview instant of an item date that is not an ISO 8601 date,
/// its own preview value and each of its `previewValues` alike.
void _validateItemPreviewDates(WidgetSpec spec, ListDataGroup group) {
  for (final field in group.fields) {
    final date = field.data;
    if (date is! HWDateTime) continue;

    final iso = date.previewIso;
    if (iso != null && date.previewDateTime == null) {
      throw GeneratorError(
        'Widget "${spec.data.name}": HWDateTime("${date.key}") of list '
        '"${group.key}" has previewValue "$iso", which is not an ISO 8601 '
        'date. $_isoDateExample',
      );
    }

    final values = field.previewValues ?? const <Object>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value is String && DateTime.tryParse(value) != null) continue;
      throw GeneratorError(
        'Widget "${spec.data.name}": previewValues[$index] of HWItemData '
        '"${date.key}" in list "${group.key}" is "$value", which is not an '
        'ISO 8601 date. $_isoDateExample',
      );
    }
  }
}

/// Rejects a list whose generated names another one already takes: a field of
/// the widget's own data, or the item class of another list.
void _validateListCollisions(WidgetSpec spec, List<ListDataGroup> groups) {
  final itemClasses = <String, ListDataGroup>{};
  for (final group in groups) {
    for (final field in spec.declaredDataFields) {
      if (field is HWLocalizedString && field.isConstant) continue;
      if (field.key != group.key) continue;
      throw GeneratorError(
        'Widget "${spec.data.name}": the key "${group.key}" is declared as '
        'the list of ${group.declarations.first.spelling} and as '
        '${_describeDataField(field)}. Both would generate the same field, so '
        'give them distinct keys.',
      );
    }

    final itemClass = group.itemClassName(spec.className);
    final other = itemClasses[itemClass];
    if (other != null) {
      throw GeneratorError(
        'Widget "${spec.data.name}": the lists "${other.key}" and '
        '"${group.key}" both generate the item class $itemClass. Rename one '
        'of them.',
      );
    }
    itemClasses[itemClass] = group;
  }
}

/// Warns about a list whose fields set `previewValues` of different lengths.
///
/// The longest decides how many sample items the gallery shows, so a field
/// with fewer entries falls back to its preview or default value past them.
void _warnAboutUnevenPreviewValues(WidgetSpec spec, ListDataGroup group) {
  HWItemData<dynamic>? longest;
  for (final field in group.fields) {
    final length = field.previewValues?.length;
    if (length == null) continue;
    if (longest == null || length > longest.previewValues!.length) {
      longest = field;
    }
  }
  if (longest == null) return;

  final count = longest.previewValues!.length;
  for (final field in group.fields) {
    final length = field.previewValues?.length;
    if (length == null || length == count) continue;

    final several = count - length > 1;
    final items = several ? 'items ${length + 1}–$count' : 'item $count';
    final fallback = _sampleFallbackOf(field.data);
    final outcome = fallback == null
        ? '${several ? 'leave' : 'leaves'} ${field.key} empty'
        : "${several ? 'fall' : 'falls'} back to ${field.key}'s $fallback";
    logger.warn(
      'Warning: Widget "${spec.data.name}": in list "${group.key}", '
      'previewValues of "${longest.key}" has $count entries, of '
      '"${field.key}" $length; $items $outcome.',
    );
  }
}

/// What a sample item past the `previewValues` of [data] shows for it, or null
/// when it shows nothing.
String? _sampleFallbackOf(HWDataType<dynamic> data) => switch (data) {
      HWLocalizedString(:final previewTranslations) =>
        previewTranslations == null
            ? 'defaultTranslations'
            : 'previewTranslations',
      HWImageData(:final previewAsset) =>
        previewAsset == null ? null : 'previewAsset',
      _ when data.previewValue != null => 'previewValue',
      _ when data.defaultValue != null => 'defaultValue',
      _ => null,
    };
