import 'package:analyzer/dart/constant/value.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

import '../dart_reserved_words.dart';

/// Decodes a [DartObject] representing a widget tree into an [HWWidget].
///
/// This uses the analyzer's constant evaluation to read the values of
/// @HomeWidget annotations and their fields.
class WidgetValueDecoder {
  final DartObject? object;

  /// The widget's default locale, from `HomeWidgetLocalization.defaultLocale`.
  ///
  /// Threaded through decoding so localized strings know which of their entries
  /// is the base value by the time any code is emitted.
  final String? defaultLocale;

  /// Namespace for the platform string resources holding constant translations,
  /// as `home_widget_<snake_widget_class>`.
  ///
  /// Threaded through decoding for the same reason as [defaultLocale]: the
  /// resource name depends on which widget the string ended up in, which only
  /// the caller knows.
  final String? resourcePrefix;

  /// Namespace for the icon font resources generated for this widget, as
  /// `hw_font_<snake_widget_class>` — what [hwFontResourcePrefix] builds.
  ///
  /// Threaded through decoding for the same reason as [resourcePrefix]: an icon
  /// font is copied per widget, so which widget an icon ended up in decides the
  /// resource it renders through.
  final String? fontResourcePrefix;

  /// The list builder whose `item` is being decoded, spelled the way an error
  /// names it (`HWRow.builder('days')`), or null outside the item of every
  /// builder.
  ///
  /// Carried along by [decodeRecursive] and set by [decodeItem], so that a
  /// builder nested anywhere inside an item is rejected.
  final String? itemScope;

  WidgetValueDecoder(
    this.object, {
    this.defaultLocale,
    this.resourcePrefix,
    this.fontResourcePrefix,
    this.itemScope,
  });

  HWWidget decode() {
    if (object == null || object!.isNull) {
      throw GeneratorError('Widget object is null');
    }

    final type = object!.type;
    final typeName = type?.element?.name;

    if (typeName == 'HWColumn') {
      return HWColumn.fromDartObject(object!, this);
    } else if (typeName == 'HWRow') {
      return HWRow.fromDartObject(object!, this);
    } else if (typeName == 'HWText') {
      return HWText.fromDartObject(object!, this);
    } else if (typeName == 'HWImage') {
      return HWImage.fromDartObject(object!);
    } else if (typeName == 'HWIcon') {
      return HWIcon.fromDartObject(object!, this);
    } else if (typeName == 'HWDataOnly') {
      return HWDataOnly.fromDartObject(object!, this);
    } else if (typeName == 'HWAdaptive') {
      return HWAdaptive.fromDartObject(object!, this);
    } else if (typeName == 'HWFill') {
      return HWFill.fromDartObject(object!, this);
    } else if (typeName == 'HWColoredBox') {
      return HWColoredBox.fromDartObject(object!, this);
    } else if (typeName == 'HWDecoratedBox') {
      return HWDecoratedBox.fromDartObject(object!, this);
    } else if (typeName == 'HWPadding') {
      return HWPadding.fromDartObject(object!, this);
    } else if (typeName == 'HWDataExists') {
      return HWDataExists.fromDartObject(object!, this);
    } else if (typeName == 'HWBoolConditional') {
      return HWBoolConditional.fromDartObject(object!, this);
    } else if (typeName == 'HWSizeAdaptive') {
      return HWSizeAdaptive.fromDartObject(object!, this);
    }

    // coverage:ignore-start
    throw GeneratorError('Unknown widget type: $typeName');
    // coverage:ignore-end
  }

  HWWidget decodeRecursive(DartObject? obj) => _decodeIn(obj, itemScope);

  /// Decodes [obj] as the `item` of [builder], spelled like [itemScope].
  HWWidget decodeItem(DartObject? obj, String builder) =>
      _decodeIn(obj, builder);

  HWWidget _decodeIn(DartObject? obj, String? itemScope) {
    return WidgetValueDecoder(
      obj,
      defaultLocale: defaultLocale,
      resourcePrefix: resourcePrefix,
      fontResourcePrefix: fontResourcePrefix,
      itemScope: itemScope,
    ).decode();
  }

  /// The constant [obj] names, matched against [values] by name.
  ///
  /// The name survives a member being inserted into the annotation's enum
  /// ahead of the one written, which the declaration index does not.
  static T? decodeEnum<T>(DartObject? obj, List<T> values) {
    if (obj == null || obj.isNull) return null;

    final variable = obj.variable;
    if (variable == null) return null;

    final name = variable.name;
    for (final value in values) {
      if (value is Enum && value.name == name) return value;
    }

    final index = obj.getField('index')?.toIntValue();
    if (index != null && index >= 0 && index < values.length) {
      return values[index];
    }
    return null;
  }

  static HWColor? decodeColor(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;
    if (typeName == 'HWFixedColor') {
      final value = obj.getField('value')?.toIntValue();
      if (value != null) return HWFixedColor(value);
    } else if (typeName == 'HWThemedColor') {
      final light = decodeColor(obj.getField('light'));
      final dark = decodeColor(obj.getField('dark'));
      if (light != null && dark != null) {
        return HWThemedColor(light: light, dark: dark);
      }
    } else if (typeName == 'HWDefaultColor') {
      final roleEnum = decodeEnum(obj.getField('role'), HWColorRole.values);
      if (roleEnum != null) return HWDefaultColor(roleEnum);
    }

    return null;
  }

  static DartObject? getField(DartObject obj, String name) {
    var field = obj.getField(name);
    if (field != null) return field;

    var superClass = obj.getField('(super)');
    while (superClass != null) {
      field = superClass.getField(name);
      if (field != null) return field;
      superClass = superClass.getField('(super)'); // coverage:ignore-line
    }
    return null;
  }

  /// Decodes an [HWTextStyle], or null when [obj] is absent.
  static HWTextStyle? decodeTextStyle(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;
    final fontSize = getField(obj, 'fontSize')?.toDoubleValue();
    final fontWeight =
        decodeEnum(getField(obj, 'fontWeight'), HWFontWeight.values);
    final color = decodeColor(getField(obj, 'color'));
    final italic = getField(obj, 'italic')?.toBoolValue();
    final underline = getField(obj, 'underline')?.toBoolValue();
    final lineThrough = getField(obj, 'lineThrough')?.toBoolValue();
    final fontFamily = getField(obj, 'fontFamily')?.toStringValue();
    final package = getField(obj, 'package')?.toStringValue();
    final androidFont = decodeAndroidFont(getField(obj, 'androidFont'));
    final baseStyle = decodeTextStyle(getField(obj, 'baseStyle'));

    if (typeName == 'HWRoleTextStyle') {
      final role = decodeEnum(getField(obj, 'role'), HWTextStyleRole.values)!;
      return HWRoleTextStyle(
        role: role,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        italic: italic,
        underline: underline,
        lineThrough: lineThrough,
        fontFamily: fontFamily,
        package: package,
        androidFont: androidFont,
        baseStyle: baseStyle,
      );
    }

    return HWTextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      italic: italic,
      underline: underline,
      lineThrough: lineThrough,
      fontFamily: fontFamily,
      package: package,
      androidFont: androidFont,
      baseStyle: baseStyle,
    );
  }

  /// Decodes an [HWAndroidFont], or null when [obj] is absent.
  static HWAndroidFont? decodeAndroidFont(DartObject? obj) {
    if (obj == null || obj.isNull) return null;
    if (getField(obj, 'isCustom')?.toBoolValue() ?? false) {
      return HWAndroidFont.custom;
    }
    final family = getField(obj, 'family')?.toStringValue();
    return family == null ? HWAndroidFont.system : HWAndroidFont.family(family);
  }

  /// The codepoint of a Flutter `IconData` constant, or null when [obj] is not
  /// one.
  static int? decodeIconCodePoint(DartObject? obj) {
    if (obj == null || obj.isNull) return null;
    return getField(obj, 'codePoint')?.toIntValue();
  }

  /// Whether a Flutter `IconData` constant mirrors in a right-to-left layout,
  /// as its `matchTextDirection` declares.
  ///
  /// False for anything that does not carry the field, including an [obj] that
  /// is not an `IconData` at all.
  static bool decodeIconMatchTextDirection(DartObject? obj) {
    if (obj == null || obj.isNull) return false;
    return getField(obj, 'matchTextDirection')?.toBoolValue() ?? false;
  }

  /// The font a Flutter `IconData` constant draws its glyph out of, or null
  /// when [obj] is not one.
  ///
  /// An icon without a family is not renderable on its own — nothing says which
  /// file the glyph lives in — so it decodes as null rather than as a font
  /// named after nothing.
  static HWIconFont? decodeIconFont(DartObject? obj) {
    if (obj == null || obj.isNull) return null;
    final family = getField(obj, 'fontFamily')?.toStringValue();
    if (family == null || family.isEmpty) return null;
    final package = getField(obj, 'fontPackage')?.toStringValue();
    return HWIconFont(
      family: family,
      package: package == null || package.isEmpty ? null : package,
    );
  }

  /// The [HWIconFont] an `HWIconFont(...)` written in a schema holds, or null
  /// when [obj] is not one.
  ///
  /// The counterpart of [decodeIconFont] for the font a schema names itself:
  /// it carries `family` and `package`, where a Flutter `IconData` carries
  /// `fontFamily` and `fontPackage`.
  static HWIconFont? decodeIconFontDeclaration(DartObject? obj) {
    if (obj == null || obj.isNull) return null;
    final family = getField(obj, 'family')?.toStringValue();
    if (family == null || family.isEmpty) return null;
    final package = getField(obj, 'package')?.toStringValue();
    return HWIconFont(
      family: family,
      package: package == null || package.isEmpty ? null : package,
    );
  }

  /// The name the generated enum gives the icon [obj], derived from the way the
  /// schema names it.
  ///
  /// `Icons.wb_sunny` becomes `wbSunny` and `CupertinoIcons.sun_max` becomes
  /// `sunMax`; an icon written as an inline `IconData(0xe88a, ...)` has no name
  /// to derive from and falls back to its codepoint, as `icon0xE88A`. A name
  /// that would collide with a Dart keyword gets a trailing underscore.
  static String decodeIconName(DartObject obj, int codePoint) {
    final declared = obj.variable?.name;
    if (declared == null) return _hexIconName(codePoint);

    final name = joinIdentifierSegments(declared, lowerFirst: true);
    if (name.isEmpty) return _hexIconName(codePoint);
    if (RegExp('^[0-9]').hasMatch(name)) return _hexIconName(codePoint);
    return _takenEnumNames.contains(name) ? '${name}_' : name;
  }

  /// The name an icon with nothing to derive one from falls back to.
  static String _hexIconName(int codePoint) =>
      'icon0x${codePoint.toRadixString(16).toUpperCase()}';

  /// The names a generated enum value cannot take: Dart's reserved words, plus
  /// the members the generated enum already carries.
  static const Set<String> _takenEnumNames = {
    ...dartReservedWords,
    'codePoint',
    'fromCodePoint',
    'hashCode',
    'icon',
    'index',
    'name',
    'noSuchMethod',
    'runtimeType',
    'toString',
    'values',
  };

  /// Decodes an [HWIconData], reading every icon's name, codepoint and font.
  ///
  /// Throws a [GeneratorError] when the icons are unusable: something other
  /// than an `IconData` in the list, icons from more than one font, no icons at
  /// all, a duplicate name, or a default or preview icon that is not one of
  /// them.
  static HWIconData decodeIconData(DartObject obj) {
    final key = getField(obj, 'key')?.toStringValue() ?? '';
    final rawIcons = getField(obj, 'icons')?.toListValue() ?? const [];

    final entries = <HWIconEntry>[];
    HWIconFont? font;
    for (final rawIcon in rawIcons) {
      final codePoint = decodeIconCodePoint(rawIcon);
      final iconFont = decodeIconFont(rawIcon);
      if (codePoint == null || iconFont == null) {
        throw GeneratorError(
          'HWIconData "$key" takes Flutter IconData values such as '
          'Icons.wb_sunny, got: ${rawIcon.type?.element?.name}',
        );
      }
      if (font != null && font != iconFont) {
        throw GeneratorError(
          'The icons of HWIconData "$key" come from more than one font '
          '($font and $iconFont). Every icon of one field is subset out of the '
          'same font file, so they all have to share it.',
        );
      }
      font = iconFont;
      entries.add(
        HWIconEntry(
          decodeIconName(rawIcon, codePoint),
          codePoint,
          matchTextDirection: decodeIconMatchTextDirection(rawIcon),
        ),
      );
    }

    if (font == null) {
      throw GeneratorError('HWIconData "$key" needs at least one icon.');
    }

    final icons = HWIconData.resolved(
      key,
      entries: entries,
      iconFont: font,
      defaultValue: _decodeNamedIcon(obj, 'defaultIcon', key: key),
      previewValue: _decodeNamedIcon(obj, 'previewIcon', key: key),
    );
    icons.validate();
    return icons;
  }

  /// The codepoint of the `IconData` under [field], or null when the field is
  /// absent or explicitly null.
  ///
  /// Throws a [GeneratorError] on a value that is present but carries no
  /// codepoint.
  static int? _decodeNamedIcon(
    DartObject obj,
    String field, {
    required String key,
  }) {
    final value = getField(obj, field);
    if (value == null || value.isNull) return null;
    final codePoint = decodeIconCodePoint(value);
    if (codePoint == null) {
      throw GeneratorError(
        'The ${field == 'defaultIcon' ? 'defaultValue' : 'previewValue'} of '
        'HWIconData "$key" takes a Flutter IconData such as Icons.wb_sunny, '
        'got: ${value.type?.element?.name}',
      );
    }
    return codePoint;
  }

  static HWEdgeInsets? decodeEdgeInsets(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final top = getField(obj, 'top')?.toDoubleValue() ?? 0.0;
    final bottom = getField(obj, 'bottom')?.toDoubleValue() ?? 0.0;
    final left = getField(obj, 'left')?.toDoubleValue() ?? 0.0;
    final right = getField(obj, 'right')?.toDoubleValue() ?? 0.0;

    return HWEdgeInsets.only(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }

  static HWBoxDecoration? decodeBoxDecoration(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    return HWBoxDecoration(
      color: decodeColor(getField(obj, 'color')),
      border: decodeBoxBorder(getField(obj, 'border')),
    );
  }

  static HWBoxBorder? decodeBoxBorder(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final color = decodeColor(getField(obj, 'color'));
    if (color == null) return null;

    return HWBoxBorder(
      radius: getField(obj, 'radius')?.toDoubleValue() ?? 0.0,
      thickness: getField(obj, 'thickness')?.toDoubleValue() ?? 0.0,
      color: color,
    );
  }

  static HWTextAlign? decodeTextAlign(DartObject? obj) {
    return decodeEnum(obj, HWTextAlign.values);
  }

  /// Decodes an [HWNumberFormat], or null when [obj] is absent.
  ///
  /// A string field the analyzer cannot evaluate decodes as empty so the
  /// validator reports it rather than the format silently changing.
  static HWNumberFormat? decodeNumberFormat(
    DartObject? obj, {
    String? defaultLocale,
    String? resourcePrefix,
  }) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;
    switch (typeName) {
      case 'HWDecimalNumberFormat':
        return HWNumberFormat.decimal(
          minimumFractionDigits:
              getField(obj, 'minimumFractionDigits')?.toIntValue(),
          maximumFractionDigits:
              getField(obj, 'maximumFractionDigits')?.toIntValue(),
          useGrouping: getField(obj, 'useGrouping')?.toBoolValue() ?? true,
        );
      case 'HWPercentNumberFormat':
        return HWNumberFormat.percent(
          minimumFractionDigits:
              getField(obj, 'minimumFractionDigits')?.toIntValue(),
          maximumFractionDigits:
              getField(obj, 'maximumFractionDigits')?.toIntValue(),
        );
      case 'HWCurrencyNumberFormat':
        final currency = decodeCurrency(
          getField(obj, 'currency'),
          defaultLocale: defaultLocale,
          resourcePrefix: resourcePrefix,
        );
        if (currency == null) {
          // coverage:ignore-start
          throw GeneratorError('HWNumberFormat.currency has no currency');
          // coverage:ignore-end
        }
        return HWNumberFormat.currency(
          currency: currency,
          decimalDigits: getField(obj, 'decimalDigits')?.toIntValue(),
        );
      case 'HWCompactNumberFormat':
        return const HWNumberFormat.compact();
      case 'HWPatternNumberFormat':
        return HWNumberFormat.pattern(
          getField(obj, 'pattern')?.toStringValue() ?? '',
        );
    }
    throw GeneratorError('Unknown number format type: $typeName');
  }

  /// Decodes an [HWDateFormat], or null when [obj] is absent.
  static HWDateFormat? decodeDateFormat(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;
    switch (typeName) {
      case 'HWSkeletonDateFormat':
        return HWDateFormat.skeleton(
          getField(obj, 'skeleton')?.toStringValue() ?? '',
        );
      case 'HWPatternDateFormat':
        return HWDateFormat.pattern(
          getField(obj, 'pattern')?.toStringValue() ?? '',
        );
      case 'HWStyledDateFormat':
        return HWDateFormat.styled(
          date: decodeEnum(getField(obj, 'date'), HWFormatStyle.values),
          time: decodeEnum(getField(obj, 'time'), HWFormatStyle.values),
        );
    }
    throw GeneratorError('Unknown date format type: $typeName');
  }

  /// Decodes an [HWCurrency], or null when [obj] is absent.
  static HWCurrency? decodeCurrency(
    DartObject? obj, {
    String? defaultLocale,
    String? resourcePrefix,
  }) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;
    switch (typeName) {
      case 'HWFixedCurrency':
        return HWCurrency.code(getField(obj, 'code')?.toStringValue() ?? '');
      case 'HWDataCurrency':
        final data = decodeDataType(
          getField(obj, 'data'),
          defaultLocale: defaultLocale,
          resourcePrefix: resourcePrefix,
        );
        if (data == null) {
          // coverage:ignore-start
          throw GeneratorError('HWCurrency.data has no data');
          // coverage:ignore-end
        }
        return HWDataCurrency(data);
    }
    throw GeneratorError('Unknown currency type: $typeName');
  }

  /// Decodes an [HWTimeZone], or null when [obj] is absent.
  static HWTimeZone? decodeTimeZone(
    DartObject? obj, {
    String? defaultLocale,
    String? resourcePrefix,
  }) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;
    switch (typeName) {
      case 'HWLocalTimeZone':
        return HWTimeZone.local;
      case 'HWNamedTimeZone':
        return HWTimeZone.named(getField(obj, 'id')?.toStringValue() ?? '');
      case 'HWDataTimeZone':
        final data = decodeDataType(
          getField(obj, 'data'),
          defaultLocale: defaultLocale,
          resourcePrefix: resourcePrefix,
        );
        if (data == null) {
          // coverage:ignore-start
          throw GeneratorError('HWTimeZone.data has no data');
          // coverage:ignore-end
        }
        return HWDataTimeZone(data);
    }
    throw GeneratorError('Unknown time zone type: $typeName');
  }

  /// Reads a `defaultTranslations` locale map, or null when [obj] is not a
  /// localized string.
  ///
  /// Dispatch is on the presence of the field rather than on the type name: a
  /// redirecting const factory is not guaranteed to report the target class,
  /// and a silent miss here would drop every translation.
  static Map<String, String>? decodeLocalizedValues(DartObject obj) =>
      decodeStringMap(getField(obj, 'defaultTranslations'));

  /// Decodes a `Map<String, String>` constant, or null when [obj] is absent or
  /// not a map.
  static Map<String, String>? decodeStringMap(DartObject? obj) {
    if (obj == null || obj.isNull) return null;

    final raw = obj.toMapValue();
    if (raw == null) return null;

    final values = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toStringValue();
      final value = entry.value?.toStringValue();
      if (key == null || value == null) continue;
      values[key] = value;
    }
    return values;
  }

  static HWDataType<dynamic>? decodeDataType(
    DartObject? obj, {
    String? defaultLocale,
    String? resourcePrefix,
  }) {
    if (obj == null || obj.isNull) return null;

    final typeName = obj.type?.element?.name;

    if (typeName == 'HWImageData') {
      final assetPath = getField(obj, 'assetPath')?.toStringValue();
      if (assetPath != null) {
        return HWImageData.asset(
          assetPath,
          package: getField(obj, 'package')?.toStringValue(),
        );
      }
      final imageKey = getField(obj, 'key')?.toStringValue();
      if (imageKey == null) return null; // coverage:ignore-line
      return HWImageData(
        imageKey,
        previewAsset: getField(obj, 'previewAsset')?.toStringValue(),
      );
    }

    if (typeName == 'HWIconData') {
      return decodeIconData(obj);
    }

    final key = getField(obj, 'key')?.toStringValue();
    if (key == null) return null;

    // Checked before HWString, of which HWLocalizedString is a subtype.
    final localizedValues = decodeLocalizedValues(obj);
    if (localizedValues != null) {
      return HWLocalizedString.resolved(
        key,
        defaultTranslations: localizedValues,
        isConstant: getField(obj, 'isConstant')?.toBoolValue() ?? false,
        defaultLocale: defaultLocale,
        previewTranslations:
            decodeStringMap(getField(obj, 'previewTranslations')),
        resourcePrefix: resourcePrefix,
      );
    }

    if (typeName == 'HWString') {
      final defaultValue = getField(obj, 'defaultValue')?.toStringValue();
      return HWString(
        key,
        defaultValue: defaultValue,
        previewValue: getField(obj, 'previewValue')?.toStringValue(),
      );
    } else if (typeName == 'HWInt') {
      final defaultValue = getField(obj, 'defaultValue')?.toIntValue();
      return HWInt(
        key,
        defaultValue: defaultValue,
        previewValue: getField(obj, 'previewValue')?.toIntValue(),
      );
    } else if (typeName == 'HWDouble') {
      final defaultValue = getField(obj, 'defaultValue')?.toDoubleValue();
      return HWDouble(
        key,
        defaultValue: defaultValue,
        previewValue: getField(obj, 'previewValue')?.toDoubleValue(),
      );
    } else if (typeName == 'HWBool') {
      final defaultValue = getField(obj, 'defaultValue')?.toBoolValue();
      return HWBool(
        key,
        defaultValue: defaultValue,
        previewValue: getField(obj, 'previewValue')?.toBoolValue(),
      );
    } else if (typeName == 'HWDateTime') {
      return HWDateTime(
        key,
        previewValue: getField(obj, 'previewIso')?.toStringValue(),
      );
    } else if (typeName == 'HWTimedData') {
      final dataObj = getField(obj, 'data');
      if (dataObj != null && dataObj.type?.element?.name == 'HWTimedData') {
        throw GeneratorError('HWTimedData cannot be nested inside HWTimedData');
      }
      final inner = decodeDataType(
        dataObj,
        defaultLocale: defaultLocale,
        resourcePrefix: resourcePrefix,
      );
      if (inner == null) return null;
      return HWTimedData(inner);
    } else if (typeName == 'HWItemData') {
      final dataObj = getField(obj, 'data');
      switch (dataObj?.type?.element?.name) {
        case 'HWTimedData':
          throw GeneratorError(
            'HWItemData cannot wrap HWTimedData. A list is time-based as a '
            'whole, so write HWTimedData(HWItemData(...)) instead.',
          );
        case 'HWJson':
          throw GeneratorError(
            'HWItemData cannot wrap HWJson. JSON objects inside a list item '
            'are not supported yet; wrap each value in an HWItemData of its '
            'own.',
          );
        case 'HWItemData':
          throw GeneratorError(
            'HWItemData cannot wrap another HWItemData. A field reads the item '
            'of the builder it sits in, so wrap it in HWItemData once.',
          );
      }
      final inner = decodeDataType(
        dataObj,
        defaultLocale: defaultLocale,
        resourcePrefix: resourcePrefix,
      );
      if (inner == null) return null;
      if (inner is HWImageData && inner.isAsset) {
        throw GeneratorError(
          'HWItemData cannot wrap the asset image "${inner.assetPath}". An '
          'asset ships with the app, so there is nothing to store per item; '
          'show it with HWImage.asset instead.',
        );
      }
      return HWItemData(
        inner,
        previewValues:
            _decodePreviewValues(getField(obj, 'previewValues'), inner),
      );
    } else if (typeName == 'HWJson') {
      final childObj = getField(obj, 'child');
      switch (childObj?.type?.element?.name) {
        case 'HWTimedData':
          throw GeneratorError(
            'HWTimedData must be a root-level data field and cannot be nested '
            'inside HWJson',
          );
        case 'HWItemData':
          throw GeneratorError(
            'An item field can\'t sit inside HWJson ("$key"). Use HWItemData '
            'on its own, inside the item of an HWColumn.builder or '
            'HWRow.builder.',
          );
      }
      final child = decodeDataType(
        childObj,
        defaultLocale: defaultLocale,
        resourcePrefix: resourcePrefix,
      );
      if (child == null) return null;
      if (child is! HWString &&
          child is! HWInt &&
          child is! HWDouble &&
          child is! HWBool &&
          child is! HWDateTime &&
          child is! HWJson &&
          child is! HWImageData &&
          child is! HWIconData) {
        return null;
      }
      return HWJson(key, child);
    }

    return null;
  }

  /// The `previewValues` of an [HWItemData] reading [field], each decoded the
  /// way [field]'s own `previewValue` is, or null when [obj] is absent.
  ///
  /// Throws a [GeneratorError] on a value that isn't a const list, on an
  /// empty list, and on an entry that is null, of a type [field] does not
  /// take, or an icon [field] does not offer.
  static List<Object>? _decodePreviewValues(
    DartObject? obj,
    HWDataType<dynamic> field,
  ) {
    if (obj == null || obj.isNull) return null;
    final entries = obj.toListValue();
    if (entries == null) {
      throw GeneratorError(
        'The previewValues of HWItemData "${field.key}" could not be read as '
        'a constant list. They must be a const list literal of values, e.g. '
        "previewValues: ['a', 'b'].",
      );
    }
    if (entries.isEmpty) {
      throw GeneratorError(
        'The previewValues of HWItemData "${field.key}" are empty. Leave them '
        'out, or list one value per sample item.',
      );
    }
    return [
      for (var index = 0; index < entries.length; index++)
        _decodePreviewValue(entries[index], field, index),
    ];
  }

  /// Entry [index] of the `previewValues` of an [HWItemData] reading [field].
  static Object _decodePreviewValue(
    DartObject entry,
    HWDataType<dynamic> field,
    int index,
  ) {
    final where = 'previewValues[$index] of HWItemData "${field.key}"';
    if (entry.isNull) {
      throw GeneratorError(
        '$where is null. List a value for every sample item.',
      );
    }
    final value = switch (field) {
      HWInt() => entry.toIntValue(),
      HWDouble() => entry.toDoubleValue() ?? entry.toIntValue()?.toDouble(),
      HWBool() => entry.toBoolValue(),
      HWIconData() => decodeIconCodePoint(entry),
      _ => entry.toStringValue(),
    };
    if (value == null) {
      throw GeneratorError(
        '$where must be ${_previewValueSpelling(field)}, got '
        '${entry.type?.element?.name}.',
      );
    }
    if (field is HWIconData && !field.codePoints.contains(value)) {
      throw GeneratorError('$where is not one of its icons.');
    }
    return value;
  }

  /// How a `previewValues` entry for [field] is written.
  static String _previewValueSpelling(HWDataType<dynamic> field) =>
      switch (field) {
        HWInt() => 'an int',
        HWDouble() => 'a number',
        HWBool() => 'a bool',
        HWIconData() => 'an IconData such as Icons.wb_sunny',
        HWDateTime() => 'an ISO 8601 String',
        HWImageData() => 'the String path of a Flutter asset',
        _ => 'a String',
      };
}
