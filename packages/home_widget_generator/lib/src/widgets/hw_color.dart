import 'hw_generatable.dart';

/// Base class for all color representations in HomeWidget.
abstract class HWColor implements HWGeneratable {
  const HWColor();

  const factory HWColor.fixed(int value) = HWFixedColor;

  const factory HWColor.themed({
    required HWColor light,
    required HWColor dark,
  }) = HWThemedColor;

  @override
  Set<String> get kotlinImports => {
        'import androidx.compose.ui.graphics.Color',
        'import androidx.glance.color.ColorProvider',
      };

  @override
  Set<String> get swiftViewModifiers => {};
}

String _getRawKotlinColor(HWColor color) {
  if (color is HWFixedColor) {
    final hexString =
        color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'Color(0x$hexString)';
  } else if (color is HWThemedColor) {
    // A themed color cannot perfectly map to a single raw Compose Color.
    // Fallback to the light color to satisfy the compiler without crashing.
    return _getRawKotlinColor(color.light);
  }
  return 'Color.White';
}

/// A fixed color defined by an ARGB integer value (e.g. `0xFFFF0000` for Red).
class HWFixedColor extends HWColor {
  final int value;

  const HWFixedColor(this.value);

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;

    return 'Color(red: ${r / 255.0}, green: ${g / 255.0}, blue: ${b / 255.0}, opacity: ${a / 255.0})';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    return HWThemedColor(light: this, dark: this)
        .toKotlin(indent, dataExpr: dataExpr);
  }
}

/// A color that adapts its output based on the system's light or dark mode.
class HWThemedColor extends HWColor {
  final HWColor light;
  final HWColor dark;

  const HWThemedColor({required this.light, required this.dark});

  @override
  Set<String> get kotlinImports => {
        ...super.kotlinImports,
        'import androidx.glance.color.ColorProvider',
        ...light.kotlinImports,
        ...dark.kotlinImports,
      };

  @override
  Set<String> get swiftViewModifiers => {
        ...super.swiftViewModifiers,
        '@Environment(\\.colorScheme) var colorScheme',
        ...light.swiftViewModifiers,
        ...dark.swiftViewModifiers,
      };

  @override
  String toSwift(int indent, {required String dataExpr}) {
    // Note: requires `@Environment(\\.colorScheme) var colorScheme` in the generated View.
    return '(colorScheme == .dark ? ${dark.toSwift(indent, dataExpr: dataExpr)} : ${light.toSwift(indent, dataExpr: dataExpr)})';
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    return 'ColorProvider(day = ${_getRawKotlinColor(light)}, night = ${_getRawKotlinColor(dark)})';
  }
}

/// The semantic roles for default system colors.
enum HWColorRole {
  /// Maps to `Color.primary` on iOS and `GlanceTheme.colors.onSurface` on Android.
  contentPrimary,

  /// Maps to `Color.secondary` on iOS and `GlanceTheme.colors.onSurfaceVariant` on Android.
  contentSecondary,

  /// Maps to `Color.tertiary` on iOS and `GlanceTheme.colors.outline` on Android.
  contentTertiary,

  /// Maps to `Color.accentColor` on iOS and `GlanceTheme.colors.primaryContainer` on Android.
  contentAccent,

  /// Maps to `Color.clear` on iOS and `GlanceTheme.colors.widgetBackground` on Android.
  defaultBackground,
}

/// A color that maps to default system semantic colors based on the given role.
class HWDefaultColor extends HWColor {
  final HWColorRole role;

  const HWDefaultColor(this.role);

  @override
  Set<String> get kotlinImports => {
        ...super.kotlinImports,
        'import androidx.glance.GlanceTheme',
      };

  @override
  String toSwift(int indent, {required String dataExpr}) {
    switch (role) {
      case HWColorRole.contentPrimary:
        return 'Color.primary';
      case HWColorRole.contentSecondary:
        return 'Color.secondary';
      case HWColorRole.contentTertiary:
        return 'Color(.tertiaryLabel)';
      case HWColorRole.contentAccent:
        return 'Color.accentColor';
      case HWColorRole.defaultBackground:
        return 'Color.clear';
    }
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    switch (role) {
      case HWColorRole.contentPrimary:
        return 'GlanceTheme.colors.onSurface';
      case HWColorRole.contentSecondary:
        return 'GlanceTheme.colors.onSurfaceVariant';
      case HWColorRole.contentTertiary:
        return 'GlanceTheme.colors.outline';
      case HWColorRole.contentAccent:
        return 'GlanceTheme.colors.primaryContainer';
      case HWColorRole.defaultBackground:
        return 'GlanceTheme.colors.widgetBackground';
    }
  }
}
