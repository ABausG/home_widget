import 'package:analyzer/dart/constant/value.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';

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

  WidgetValueDecoder(this.object, {this.defaultLocale, this.resourcePrefix});

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
    }

    // coverage:ignore-start
    throw GeneratorError('Unknown widget type: $typeName');
    // coverage:ignore-end
  }

  HWWidget decodeRecursive(DartObject? obj) {
    return WidgetValueDecoder(
      obj,
      defaultLocale: defaultLocale,
      resourcePrefix: resourcePrefix,
    ).decode();
  }

  static T? decodeEnum<T>(DartObject? obj, List<T> values) {
    if (obj == null || obj.isNull) return null;

    final variable = obj.variable;
    if (variable != null) {
      final index = obj.getField('index')?.toIntValue();
      if (index != null && index >= 0 && index < values.length) {
        return values[index];
      }
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
      baseStyle: baseStyle,
    );
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
        resourcePrefix: resourcePrefix,
      );
    }

    if (typeName == 'HWString') {
      final defaultValue = getField(obj, 'defaultValue')?.toStringValue();
      return HWString(key, defaultValue: defaultValue);
    } else if (typeName == 'HWInt') {
      final defaultValue = getField(obj, 'defaultValue')?.toIntValue();
      return HWInt(key, defaultValue: defaultValue);
    } else if (typeName == 'HWDouble') {
      final defaultValue = getField(obj, 'defaultValue')?.toDoubleValue();
      return HWDouble(key, defaultValue: defaultValue);
    } else if (typeName == 'HWBool') {
      final defaultValue = getField(obj, 'defaultValue')?.toBoolValue();
      return HWBool(key, defaultValue: defaultValue);
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
    } else if (typeName == 'HWJson') {
      final childObj = getField(obj, 'child');
      if (childObj != null && childObj.type?.element?.name == 'HWTimedData') {
        throw GeneratorError(
          'HWTimedData must be a root-level data field and cannot be nested '
          'inside HWJson',
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
          child is! HWJson) {
        return null;
      }
      return HWJson(key, child);
    }

    return null;
  }
}
