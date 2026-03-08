import 'package:analyzer/dart/constant/value.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/src/generator_error.dart';

/// Decodes a [DartObject] representing a widget tree into an [HWWidget].
///
/// This uses the analyzer's constant evaluation to read the values of
/// @HomeWidget annotations and their fields.
class WidgetValueDecoder {
  final DartObject? object;

  WidgetValueDecoder(this.object);

  HWWidget decode() {
    if (object == null || object!.isNull) {
      throw GeneratorError('Widget object is null');
    }

    final type = object!.type;
    final typeName = type?.element3?.name3;

    if (typeName == 'HWColumn') {
      return HWColumn.fromDartObject(object!, this);
    } else if (typeName == 'HWRow') {
      return HWRow.fromDartObject(object!, this);
    } else if (typeName == 'HWText') {
      return HWText.fromDartObject(object!);
    } else if (typeName == 'HWDataOnly') {
      return HWDataOnly.fromDartObject(object!);
    } else if (typeName == 'HWAdaptive') {
      return HWAdaptive.fromDartObject(object!, this);
    } else if (typeName == 'HWFill') {
      return HWFill.fromDartObject(object!, this);
    } else if (typeName == 'HWColoredBox') {
      return HWColoredBox.fromDartObject(object!, this);
    }

    throw GeneratorError('Unknown widget type: $typeName');
  }

  HWWidget decodeRecursive(DartObject? obj) {
    return WidgetValueDecoder(obj).decode();
  }

  static T? decodeEnum<T>(DartObject? obj, List<T> values) {
    if (obj == null || obj.isNull) return null;

    final variable = obj.variable2;
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

    final typeName = obj.type?.element3?.name3;
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
}
