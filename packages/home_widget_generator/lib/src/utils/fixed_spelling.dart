import '../types.dart';

/// [value], a fixed value, the way a schema writes it.
String spellFixedValue(HWDataType<dynamic> value) => switch (value) {
      HWLocalizedString() => 'HWString.localizedFixed',
      HWString(:final fixedValue) => 'HWString.fixed("$fixedValue")',
      HWDateTime(:final fixedIso) => 'HWDateTime.fixed("$fixedIso")',
      HWImageData(:final assetPath) => 'HWImageData.asset("$assetPath")',
      HWIconData() => 'HWIconData.fixed',
      HWInt(:final fixedValue) => 'HWInt.fixed($fixedValue)',
      HWDouble(:final fixedValue) => 'HWDouble.fixed($fixedValue)',
      HWBool(:final fixedValue) => 'HWBool.fixed($fixedValue)',
      HWFixedColor(:final value) => 'HWColor.fixed(${hwArgbLiteral(value)})',
      HWDefaultColor(:final role) => 'HWDefaultColor(HWColorRole.${role.name})',
      HWColor() ||
      HWJson() ||
      HWTimedData() ||
      HWItemData() ||
      HWPayload() ||
      HWAppearanceData() =>
        '${value.runtimeType}',
    };
