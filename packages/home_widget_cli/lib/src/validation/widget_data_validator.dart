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
/// Which plural form or substitution applies depends on runtime data, so a
/// number or a date belongs in an [HWText.number] / [HWText.dateTime] of its
/// own, and anything else has to be pushed through a plain [HWString].
final RegExp _placeholderPattern = RegExp(r'\{[A-Za-z0-9_]+\}|%[sdf@]|%\d+\$');

/// The shape of an ISO 4217 currency code, which is upper-case by definition.
final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

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

  _validateWidgetUrls(spec);
  _validateFlavors(spec);
  _validateImageKeys(spec);
  _validateNoConflictingKeys(spec);
  _validatePreviewDates(spec);
  validateLocalization(spec);
  _validateConditionalData(spec);
  _validateTimedDataKeys(spec);
  _validateTextFormats(spec);

  for (final group in [...spec.jsonDataGroups, ...spec.timedJsonDataGroups]) {
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

/// Rejects a widget URL that is not an absolute [Uri] with a scheme.
void _validateWidgetUrls(WidgetSpec spec) {
  _validateWidgetUrl(spec, spec.data.widgetUrl, platform: null);
  _validateWidgetUrl(spec, spec.data.android?.widgetUrl, platform: 'Android');
  _validateWidgetUrl(spec, spec.data.iOS?.widgetUrl, platform: 'iOS');
}

void _validateWidgetUrl(
  WidgetSpec spec,
  String? url, {
  required String? platform,
}) {
  if (url == null) return;

  final where = platform == null ? 'widgetUrl' : '$platform widgetUrl';

  if (url.trim().isEmpty) {
    throw GeneratorError(
      'Widget "${spec.data.name}": $where is empty. Omit it to keep the widget '
      'from opening the app when tapped.',
    );
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    throw GeneratorError(
      'Widget "${spec.data.name}": $where "$url" is not a valid URL. A '
      'widgetUrl must be an absolute URI including a scheme, e.g. '
      'myapp://details.',
    );
  }
}

/// Rejects a flavor map that would generate nothing, or that overrides a
/// platform the widget is not configured for.
void _validateFlavors(WidgetSpec spec) {
  final flavors = spec.data.flavors;
  if (flavors == null) return;

  if (flavors.isEmpty) {
    throw GeneratorError(
      'Widget "${spec.data.name}": flavors is empty, so the widget would exist '
      'in no flavor at all. Omit flavors to generate it for every flavor.',
    );
  }

  for (final entry in flavors.entries) {
    final name = entry.key;
    if (name.trim().isEmpty) {
      throw GeneratorError(
        'Widget "${spec.data.name}": a flavor name is empty. Name the flavor '
        'exactly as the native project spells it, e.g. "dev".',
      );
    }

    final flavor = entry.value;
    if (flavor.iOS != null && spec.data.iOS == null) {
      throw GeneratorError(
        'Widget "${spec.data.name}": flavor "$name" carries iOS overrides but '
        'the widget has no iOS: HomeWidgetIOSConfiguration(...), so no iOS '
        'widget is generated for it to override.',
      );
    }
    final groupId = flavor.iOS?.groupId;
    if (groupId != null && groupId.trim().isEmpty) {
      throw GeneratorError(
        'Widget "${spec.data.name}": flavor "$name" has an empty iOS groupId. '
        'Omit it to keep the App Group of the base configuration.',
      );
    }
  }
}

/// Rejects distinct images that would share one storage key.
///
/// Identical asset paths collapse into a single field (value equality on
/// [HWImageData]), but two different sources deriving the same key -- e.g.
/// `assets/logo.png` and `assets-logo.png`, both `assetsLogoPng` -- give one
/// key two conflicting meanings, so which image the key stands for is
/// ambiguous wherever it is referenced.
void _validateImageKeys(WidgetSpec spec) {
  final seen = <String, HWImageData>{};
  for (final image in spec.imageDataFields) {
    final existing = seen[image.key];
    // Compare effective asset keys so the two spellings of one package asset
    // (`package:` vs a manual `packages/<pkg>/` path) are not a conflict.
    if (existing != null &&
        existing.effectiveAssetKey != image.effectiveAssetKey) {
      throw GeneratorError(
        'Conflicting image data key "${image.key}": '
        '${_describeImage(existing)} and ${_describeImage(image)} '
        'map to the same key. Rename one of them.',
      );
    }
    seen[image.key] = image;
  }
}

String _describeImage(HWImageData image) {
  if (!image.isAsset) return 'runtime image "${image.key}"';
  final package = image.package;
  if (package == null) return 'asset "${image.assetPath}"';
  return 'asset "${image.assetPath}" of package "$package"';
}

void _validateDataTypeKeys(HWDataType<dynamic> type) {
  // Constant localized strings are inlined and never named in generated APIs,
  // so they deliberately carry an empty key.
  if (type is HWLocalizedString && type.isConstant) return;

  if (type is HWTimedData<dynamic>) {
    final inner = type.data;
    if (inner is HWImageData && inner.isAsset) {
      throw GeneratorError(
        'HWTimedData cannot wrap HWImageData.asset("${inner.assetPath}"): an '
        'asset ships with the app and never changes, so there is nothing for a '
        'timeline to switch between. Use HWTimedData(HWImageData("key")) and '
        'save one image per timestamp, or pick between assets with a '
        'conditional.',
      );
    }
    _validateDataTypeKeys(inner);
    return;
  }
  _validateAsciiIdentifier(type.key, descriptor: _describeLeafContext(type));
  if (type is HWJson) {
    if (type.child is HWTimedData) {
      throw GeneratorError(
        'HWTimedData must be a root-level data field and cannot be nested '
        'inside HWJson.',
      );
    }
    final leaf = type.leafType;
    if (leaf is HWImageData && leaf.isAsset) {
      throw GeneratorError(
        'HWJson cannot carry HWImageData.asset("${leaf.assetPath}") (in '
        '"${type.key}"): an asset is read straight out of the app bundle, so '
        'there is nothing for the group\'s blob to carry. Use HWImage.asset '
        'directly, or a runtime HWImageData("key") leaf.',
      );
    }
    _validateDataTypeKeys(type.child);
  }
}

/// Rejects conditionals whose branch can never be taken.
///
/// Only [HWDataExists] is null-check shaped. [HWBoolConditional] rejects
/// anything that is not an `HWBool` (or an `HWJson` wrapping one) while
/// decoding, so a localized string can never reach it.
void _validateConditionalData(WidgetSpec spec) {
  for (final widget in spec.effectiveWidgetTree.descendants) {
    if (widget is! HWDataExists) continue;
    final data = widget.data.unwrapped;

    if (data is HWImageData && data.isAsset) {
      throw GeneratorError(
        'Widget "${spec.data.name}": HWDataExists cannot test '
        'HWImageData.asset("${data.assetPath}"). An asset ships with the app '
        'and is read straight out of the bundle, so it stores no value to '
        'check — the check is always true and the whenAbsent branch is never '
        'rendered. Render HWImage.asset directly, or use a runtime '
        'HWImageData("key") if you want to switch on whether an image was '
        'saved.',
      );
    }

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

/// Rejects a formatted text whose data or format could not render.
///
/// Formats are const values written in the annotation, so every mistake here is
/// knowable at build time; without these checks a currency code that is not a
/// code, or a styled date asking for neither a date nor a time, would only show
/// up as wrong text on a device.
void _validateTextFormats(WidgetSpec spec) {
  for (final widget in spec.effectiveWidgetTree.descendants) {
    if (widget is! HWText) continue;
    final data = widget.dataType;

    final dateFormat = widget.dateFormat;
    if (dateFormat != null) {
      if (data != null && dateTimeLeafOf(data) == null) {
        // coverage:ignore-start
        throw GeneratorError(
          'Widget "${spec.data.name}": HWText.dateTime needs an HWDateTime, '
          'but "${data.key}" is ${_describeBoundLeaf(data)}. Bind an '
          'HWDateTime, or render the value with a plain HWText.',
        );
        // coverage:ignore-end
      }
      _validateDateFormat(spec, dateFormat);
      _validateTimeZone(spec, widget.timeZone);
    }

    final numberFormat = widget.numberFormat;
    if (numberFormat != null) {
      if (data != null && numberLeafOf(data) == null) {
        // coverage:ignore-start
        throw GeneratorError(
          'Widget "${spec.data.name}": HWText.number needs an HWInt or '
          'HWDouble, but "${data.key}" is ${_describeBoundLeaf(data)}. Bind a '
          'number, or render the value with a plain HWText.',
        );
        // coverage:ignore-end
      }
      _validateNumberFormat(spec, numberFormat);
    }
  }
}

void _validateNumberFormat(WidgetSpec spec, HWNumberFormat format) {
  switch (format) {
    case HWDecimalNumberFormat(
        :final minimumFractionDigits,
        :final maximumFractionDigits,
      ):
      _validateFractionDigits(
        spec,
        descriptor: 'HWNumberFormat.decimal',
        minimum: minimumFractionDigits,
        maximum: maximumFractionDigits,
      );
    case HWPercentNumberFormat(
        :final minimumFractionDigits,
        :final maximumFractionDigits,
      ):
      _validateFractionDigits(
        spec,
        descriptor: 'HWNumberFormat.percent',
        minimum: minimumFractionDigits,
        maximum: maximumFractionDigits,
      );
    case HWCurrencyNumberFormat(:final currency, :final decimalDigits):
      _validateDigitCount(
        spec,
        descriptor: 'HWNumberFormat.currency',
        parameter: 'decimalDigits',
        value: decimalDigits,
      );
      _validateCurrency(spec, currency);
    case HWPatternNumberFormat(:final pattern):
      if (pattern.trim().isEmpty) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWNumberFormat.pattern is empty. Give '
          'it an ICU decimal pattern, e.g. "#,##0.00".',
        );
      }
    case HWCompactNumberFormat():
      break;
  }
}

void _validateCurrency(WidgetSpec spec, HWCurrency currency) {
  switch (currency) {
    case HWFixedCurrency(:final code):
      if (!_currencyCodePattern.hasMatch(code)) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWCurrency.code("$code") is not an ISO '
          '4217 code. Use exactly three upper-case ASCII letters, e.g. "EUR".',
        );
      }
    case HWDataCurrency(:final data):
      _validatePlainStringData(
        spec,
        data,
        descriptor: 'HWCurrency.data',
        subject: 'An ISO 4217 code',
      );
  }
}

void _validateDateFormat(WidgetSpec spec, HWDateFormat format) {
  switch (format) {
    case HWSkeletonDateFormat(:final skeleton):
      if (skeleton.trim().isEmpty) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWDateFormat.skeleton is empty. Give it '
          'ICU field letters, e.g. "yMMMd", or use one of the named constants '
          'such as HWDateFormat.yMMMd.',
        );
      }
    case HWPatternDateFormat(:final pattern):
      if (pattern.trim().isEmpty) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWDateFormat.pattern is empty. Give it '
          'an ICU pattern, e.g. "dd.MM.yyyy HH:mm".',
        );
      }
    case HWStyledDateFormat(:final date, :final time):
      if (date == null && time == null) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWDateFormat.styled has neither a date '
          'nor a time style, so it would render nothing. Set at least one of '
          'them.',
        );
      }
  }
}

void _validateTimeZone(WidgetSpec spec, HWTimeZone timeZone) {
  switch (timeZone) {
    case HWNamedTimeZone(:final id):
      if (id.trim().isEmpty) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWTimeZone.named is empty. Use an IANA '
          'zone id, e.g. "Europe/Berlin", or HWTimeZone.local for the '
          "device's own zone.",
        );
      }
    case HWDataTimeZone(:final data):
      _validatePlainStringData(
        spec,
        data,
        descriptor: 'HWTimeZone.data',
        subject: 'An IANA zone id',
      );
    case HWLocalTimeZone():
      break;
  }
}

/// Rejects a format-level data field that is not a plain string.
///
/// [descriptor] names the construct reading it and [subject] what it holds, so
/// the message says why the value cannot be translated or numeric.
void _validatePlainStringData(
  WidgetSpec spec,
  HWDataType<dynamic> data, {
  required String descriptor,
  required String subject,
}) {
  final leaf = _leafOf(data);
  if (leaf is HWLocalizedString) {
    throw GeneratorError(
      'Widget "${spec.data.name}": $descriptor("${data.key}") reads a '
      'localized string. $subject is the same in every language, so store it '
      'in a plain HWString.',
    );
  }
  if (leaf is! HWString) {
    throw GeneratorError(
      'Widget "${spec.data.name}": $descriptor needs an HWString, but '
      '"${data.key}" is ${_describeBoundLeaf(data)}. $subject is stored as '
      'text.',
    );
  }
}

void _validateFractionDigits(
  WidgetSpec spec, {
  required String descriptor,
  int? minimum,
  int? maximum,
}) {
  _validateDigitCount(
    spec,
    descriptor: descriptor,
    parameter: 'minimumFractionDigits',
    value: minimum,
  );
  _validateDigitCount(
    spec,
    descriptor: descriptor,
    parameter: 'maximumFractionDigits',
    value: maximum,
  );
  if (minimum != null && maximum != null && minimum > maximum) {
    throw GeneratorError(
      'Widget "${spec.data.name}": $descriptor has minimumFractionDigits '
      '$minimum above maximumFractionDigits $maximum, which no number can '
      'satisfy. Swap them, or drop one and let the locale decide.',
    );
  }
}

void _validateDigitCount(
  WidgetSpec spec, {
  required String descriptor,
  required String parameter,
  required int? value,
}) {
  if (value == null || value >= 0) return;
  throw GeneratorError(
    'Widget "${spec.data.name}": $descriptor has $parameter $value. A digit '
    'count cannot be negative.',
  );
}

/// The type a data field ultimately describes: a time-based wrapper stripped
/// and a JSON path descended, the way `numberLeafOf` and friends do it.
HWDataType<dynamic> _leafOf(HWDataType<dynamic> type) {
  final unwrapped = type.unwrapped;
  return unwrapped is HWJson ? unwrapped.leafType : unwrapped;
}

String _describeBoundLeaf(HWDataType<dynamic> data) {
  final unwrapped = data.unwrapped;
  if (unwrapped is HWJson) {
    return '${unwrapped.leafType.runtimeType} at its JSON leaf';
  }
  return '${unwrapped.runtimeType}';
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
    // The gallery preview resolves preview text through the same chain the
    // widget resolves its shipped text with, so an incomplete map would leave a
    // locale previewing nothing.
    _validateLocaleMap(
      field.previewTranslations,
      supported: supported,
      descriptor: '$descriptor previewTranslations',
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
        'form or substitution applies depends on runtime data, so a locale map '
        'cannot hold it. Render a number with HWText.number and a date with '
        'HWText.dateTime — both format themselves in the device locale — or '
        'build the string in your app and push it through a plain HWString.',
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
  for (final field in spec.declaredDataFields) {
    if (field is HWLocalizedString && field.isConstant) continue;

    final existing = seen[field.key];
    if (existing == null) {
      seen[field.key] = field;
      continue;
    }
    // Compatible declarations describe one field between them; the merged one
    // is carried forward so a third declaration is checked against everything
    // set so far. This is the same fold `WidgetSpec.dataFields` performs.
    if (existing.isCompatibleWith(field)) {
      seen[field.key] = existing.mergedWith(field);
      continue;
    }
    if (existing is HWJson && field is HWJson) continue;

    // Timed HWJson declarations merge into one group per root key, exactly like
    // untimed ones; the merged group maps onto a single entry in the timed JSON
    // file.
    if (existing is HWTimedData &&
        field is HWTimedData &&
        existing.unwrapped is HWJson &&
        field.unwrapped is HWJson) {
      continue;
    }

    if (existing is HWLocalizedString && field is HWLocalizedString) {
      final subject = _sameTranslations(
        existing.defaultTranslations,
        field.defaultTranslations,
      )
          ? 'different previewTranslations'
          : 'different translations';
      throw GeneratorError(
        'Widget "${spec.data.name}": two HWString.localized("${field.key}") '
        'entries declare $subject. Give them distinct keys.',
      );
    }

    // Two spellings of the same package asset (`package:` vs a manual
    // `packages/<pkg>/` path) derive the same key and are compatible, so they
    // were already merged above; [_validateImageKeys] gives the more specific
    // diagnostic for genuine image key collisions. What is left here is a key
    // given two different previewAssets, which the message below names.

    throw GeneratorError(
      'Widget "${spec.data.name}": the key "${field.key}" is declared as '
      '${_describeDataField(existing)} and ${_describeDataField(field)}. '
      'Both would generate the same field, so give them distinct keys.',
    );
  }
}

/// Names [field] the way its declaration reads, down to the values that make
/// two declarations of one key disagree.
String _describeDataField(HWDataType<dynamic> field) {
  if (field is HWTimedData) {
    return 'HWTimedData(${_describeDataField(field.data)})';
  }
  if (field is HWLocalizedString) {
    final preview = field.previewTranslations;
    if (preview == null) return 'HWString.localized';
    return 'HWString.localized(previewTranslations: $preview)';
  }
  if (field is HWJson) return 'HWJson';
  if (field is HWImageData) {
    final preview = field.previewAsset;
    if (preview == null) return '${field.runtimeType}';
    return '${field.runtimeType}(previewAsset: "$preview")';
  }

  final arguments = <String>[
    if (field.defaultValue != null) 'defaultValue: ${field.defaultValue}',
    if (_previewArgument(field) case final preview?) 'previewValue: $preview',
  ];
  if (arguments.isEmpty) return '${field.runtimeType}';
  return '${field.runtimeType}(${arguments.join(', ')})';
}

/// The preview value of [field] as written, or null when it sets none.
///
/// A date is reported as its ISO text rather than as the parsed instant, since
/// that is what the annotation spells and what a conflict is about.
String? _previewArgument(HWDataType<dynamic> field) {
  if (field is HWDateTime) {
    final iso = field.previewIso;
    return iso == null ? null : '"$iso"';
  }
  final preview = field.previewValue;
  if (preview == null) return null;
  return preview is String ? '"$preview"' : '$preview';
}

bool _sameTranslations(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Rejects a preview instant that is not an ISO 8601 date.
///
/// [HWDateTime] keeps the text it was written with, because [DateTime] has no
/// const constructor an annotation could carry; a typo there would otherwise
/// silently render the preview without a date.
void _validatePreviewDates(WidgetSpec spec) {
  for (final field in spec.dataFields) {
    for (final leaf in _dataLeaves(field)) {
      if (leaf is! HWDateTime) continue;
      final iso = leaf.previewIso;
      if (iso == null || leaf.previewDateTime != null) continue;
      throw GeneratorError(
        'Widget "${spec.data.name}": HWDateTime("${leaf.key}") has previewValue '
        '"$iso", which is not an ISO 8601 date. Write the instant as e.g. '
        '"2024-03-08T09:41:00Z".',
      );
    }
  }
}

/// [field] down to the types that carry values: time-based wrappers stripped
/// and JSON paths descended.
Iterable<HWDataType<dynamic>> _dataLeaves(HWDataType<dynamic> field) sync* {
  switch (field) {
    case HWTimedData<dynamic>():
      yield* _dataLeaves(field.data);
    case HWJson<dynamic>():
      yield* _dataLeaves(field.child);
    default:
      yield field;
  }
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
        // Compatible leaves describe one property between them, so the merged
        // one takes the slot and a third declaration is checked against it.
        // Compared as the [HWJson] declarations they came from, since a leaf
        // default is inlined at every site rendering the path and so has to
        // agree, which the leaf types alone do not require.
        final existing = _jsonDeclarationOf(jsonRootKey, slot.leafField!);
        final incoming = _jsonDeclarationOf(jsonRootKey, field);
        if (existing.isCompatibleWith(incoming)) {
          slot.leafField = JsonDataField(
            path: field.path,
            type: (existing.mergedWith(incoming) as HWJson<dynamic>).leafType,
          );
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

/// [field] rebuilt as the [HWJson] declaration it was flattened from, so that
/// two leaves at one path are compared by that type's own rule.
HWJson<dynamic> _jsonDeclarationOf(String jsonRootKey, JsonDataField field) {
  var wrapped = field.type;
  for (final segment in field.path.reversed.skip(1)) {
    wrapped = HWJson<dynamic>(segment, wrapped);
  }
  return HWJson<dynamic>(jsonRootKey, wrapped);
}

String _dotted(List<String> segments) =>
    segments.isEmpty ? '<root>' : segments.join('.');

String _fieldSummaryIncoming(JsonDataField field) =>
    'Conflicting declaration: ${_fieldSummary(field)}.';

String _fieldSummary(JsonDataField field) {
  final dv = field.type.defaultValue;
  final dvText = dv == null ? 'no default' : 'default=$dv';
  final preview = _previewArgument(field.type);
  final previewText = preview == null ? '' : ', preview=$preview';
  return '${field.path.join('.')} → '
      '${field.type.runtimeType} (${field.type.key}, $dvText$previewText)';
}

String _jsonConflictMessage(String jsonRootKey, {required String reason}) =>
    'Conflicting JSON paths in JSON group "$jsonRootKey": $reason';
