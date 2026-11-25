import '../appearance.dart';
import '../native_helpers.dart';
import '../types.dart';

/// The color content renders in when nothing names one.
///
/// SwiftUI hands an unstyled `Text` this color itself; a Glance one falls back
/// to opaque black, so the Android output names it explicitly.
const HWColor hwDefaultContentColor =
    HWDefaultColor(HWColorRole.contentPrimary);

/// The Kotlin imports naming [hwDefaultContentColor] needs.
const Set<String> hwDefaultContentColorKotlinImports = {
  'import androidx.glance.GlanceTheme',
};

/// What a color slot paints with while its color has no value.
///
/// Codegen-internal: consumed by the widgets and by `home_widget_cli`, not by
/// app code.
enum HWColorSlotDefault {
  /// The default content color, which text and icons render in.
  content(
    swift: 'Color.primary',
    kotlin: 'GlanceTheme.colors.onSurface',
    kotlinImports: hwDefaultContentColorKotlinImports,
  ),

  /// Nothing: a fill or a border keeps its room but paints transparent.
  transparent(
    swift: 'Color.clear',
    kotlin: 'ColorProvider(day = Color.Transparent, night = Color.Transparent)',
    kotlinImports: {
      'import androidx.compose.ui.graphics.Color',
      'import androidx.glance.color.ColorProvider',
    },
  ),

  /// The platform's own widget background, which a widget's
  /// `backgroundColor` falls back to.
  ///
  /// iOS keeps the system's container background instead of painting a
  /// color, which the generated container background modifier decides.
  background(
    swift: 'Color(.systemBackground)',
    kotlin: 'GlanceTheme.colors.widgetBackground',
    kotlinImports: {'import androidx.glance.GlanceTheme'},
  );

  const HWColorSlotDefault({
    required this.swift,
    required this.kotlin,
    required this.kotlinImports,
  });

  /// The SwiftUI `Color` painted instead.
  final String swift;

  /// The Glance `ColorProvider` painted instead.
  final String kotlin;

  /// The imports [kotlin] needs.
  final Set<String> kotlinImports;
}

/// Whether [color] always has a value, so its emitted Swift expression is not
/// an optional: a constant color, and nothing else.
bool hwIsConstantColor(HWDataType<dynamic> color) =>
    color is HWFixedColor || color is HWDefaultColor;

/// The SwiftUI `Color` [color] paints with, an optional unless it is
/// constant.
///
/// [color] is any color value — constant, stored, wrapped in an [HWJson],
/// [HWTimedData] or [HWItemData], or an [HWAppearanceData] picking one;
/// [dataExpr] is the expression the data class is reached through.
String hwSwiftColorValue(HWDataType<dynamic> color, String dataExpr) {
  if (color is HWAppearanceData) {
    return color.swiftPick((side) => hwSwiftColorValue(side, dataExpr));
  }
  if (color is HWFixedColor) return color.swiftLiteral;
  if (color is HWDefaultColor) return color.swiftLiteral;
  return '${HWNativeHelper.hwColor.name}(${color.swiftReadExpr(dataExpr)})';
}

/// The SwiftUI `Color` a slot paints with for [color], falling back to
/// [fallback] while the color has no value.
///
/// With [fallback] null the expression stays an optional, for a slot such as
/// `foregroundColor` that reads nil as its own default.
String hwSwiftColor(
  HWDataType<dynamic> color, {
  required String dataExpr,
  HWColorSlotDefault? fallback,
}) {
  final value = hwSwiftColorValue(color, dataExpr);
  if (fallback == null || hwIsConstantColor(color)) return value;
  return '($value ?? ${fallback.swift})';
}

/// The Glance `ColorProvider` [color] paints with, nullable unless
/// [_kotlinColorIsConstant].
///
/// An [HWAppearanceData] is one `ColorProvider` holding the color of either
/// appearance, which the launcher switches between itself.
String _kotlinColorValue(HWDataType<dynamic> color, String dataExpr) {
  if (color is HWAppearanceData) {
    final pair = _kotlinFixedPair(color);
    if (pair != null) return pair;
    return HWAppearanceChoice.kotlinColor(
      light: _kotlinColorValue(color.light, dataExpr),
      dark: _kotlinColorValue(color.dark, dataExpr),
    );
  }
  if (color is HWFixedColor) {
    return HWAppearanceChoice.kotlinColorPair(
      light: color.kotlinLiteral,
      dark: color.kotlinLiteral,
    );
  }
  if (color is HWDefaultColor) return color.kotlinLiteral;
  return '${HWNativeHelper.hwColor.name}(${color.kotlinReadExpr(dataExpr)})';
}

/// The `ColorProvider` of the two constant colors [color] picks between, or
/// null when one of its sides is not a constant ARGB color.
String? _kotlinFixedPair(HWAppearanceData<dynamic> color) {
  final light = color.light;
  final dark = color.dark;
  if (light is! HWFixedColor || dark is! HWFixedColor) return null;
  return HWAppearanceChoice.kotlinColorPair(
    light: light.kotlinLiteral,
    dark: dark.kotlinLiteral,
  );
}

/// Whether the Glance expression for [color] is never null.
bool _kotlinColorIsConstant(HWDataType<dynamic> color) =>
    hwIsConstantColor(color) ||
    (color is HWAppearanceData && _kotlinFixedPair(color) != null);

/// The Glance `ColorProvider` a slot paints with for [color], falling back to
/// [fallback] while the color has no value.
String hwKotlinColor(
  HWDataType<dynamic> color, {
  required String dataExpr,
  required HWColorSlotDefault fallback,
}) {
  final value = _kotlinColorValue(color, dataExpr);
  if (_kotlinColorIsConstant(color)) return value;
  return '($value ?: ${fallback.kotlin})';
}

/// The Kotlin imports [hwKotlinColor] needs for [color], besides those of the
/// helpers it calls.
Set<String> hwKotlinColorImports(
  HWDataType<dynamic> color, {
  required HWColorSlotDefault fallback,
}) =>
    {
      ...HWAppearanceChoice.kotlinColorPairImports,
      if (color.readValues.any((value) => value is HWDefaultColor))
        'import androidx.glance.GlanceTheme',
      if (!_kotlinColorIsConstant(color)) ...fallback.kotlinImports,
    };
