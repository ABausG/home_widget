part of '../types.dart';

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

/// A color, accepted by every color slot: a text style, an icon, an
/// `HWColoredBox`, the fill and border of an `HWBoxDecoration` and the
/// `backgroundColor` of the Android and iOS configurations.
///
/// Three forms:
/// - `HWColor('accent', defaultValue: 0xFF6750A4)` -- a color the app stores
///   at runtime through the generated `saveData(accent: ...)`, which takes a
///   Flutter `Color`.
/// - `HWColor.fixed(0xFF6750A4)` -- a constant ARGB color.
/// - `HWDefaultColor(HWColorRole.contentPrimary)` -- a system color role.
///
/// A stored color works inside [HWJson], [HWTimedData] and [HWItemData] like
/// any other stored value. While nothing is stored, a slot paints with
/// [defaultValue], and without one with its own default: the default content
/// color for text and icons, nothing for a fill or a border, and the platform
/// background for a `backgroundColor`. A stored transparent color is a value
/// like any other.
///
/// Wrap colors in an [HWAppearanceData] to pick one by the system appearance.
class HWColor extends HWDataType<int> {
  /// The ARGB color a slot paints with while nothing is stored, written like
  /// [HWColor.fixed]'s, e.g. `0xFF6750A4`.
  @override
  final int? defaultValue;

  /// The ARGB color the widget gallery shows while nothing is stored.
  @override
  final int? previewValue;

  /// A color stored under [key].
  const HWColor(super.key, {this.defaultValue, this.previewValue});

  /// A constant color defined by an ARGB integer, e.g. `0xFFFF0000` for red.
  const factory HWColor.fixed(int value) = HWFixedColor;

  /// The stored value is the color's 32-bit ARGB integer.
  @override
  String get dartType => 'int';

  /// The generated Dart API hands over and back a Flutter `Color`.
  @override
  String dartApiType(String widgetClassName) => 'Color';

  /// The generated helper turning a stored ARGB integer back into a `Color`,
  /// which `home_widget_cli` emits next to every widget storing a color.
  static const String dartDecodeFunction = r'_$color';

  @override
  String dartDecode(String expr, String widgetClassName) =>
      '$dartDecodeFunction($expr)';

  /// A wide-gamut color is converted to sRGB, which is all an 8-bit ARGB
  /// value holds.
  @override
  String? dartEncode(String expr, String widgetClassName) =>
      '$expr.withValues(colorSpace: ColorSpace.sRGB).toARGB32()';

  @override
  String? codegenDartDefaultLiteral() {
    final value = defaultValue;
    return value == null ? null : hwArgbLiteral(value);
  }

  @override
  String get kotlinType => 'Long';

  @override
  String get swiftType => 'Int';

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final fallback = codegenKotlinFallbackLiteral(preview: preview) ?? 'null';
    // A Dart int is stored as an Int only while it fits 32 bits, and an opaque
    // color does not.
    return 'if ($store.contains("$key")) '
        '(try { $store.getInt("$key", 0).toLong() } '
        'catch (_: ClassCastException) { $store.getLong("$key", 0L) }) '
        'else $fallback';
  }

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) {
    final read = '$store?.object(forKey: "$key") as? Int';
    final fallback = codegenSwiftFallbackLiteral(preview: preview);
    if (fallback != null) return '($read ?? $fallback)';
    return read;
  }

  @override
  String? codegenKotlinDefaultLiteral() =>
      defaultValue == null ? null : kotlinLongLiteral(defaultValue!);

  @override
  String? codegenSwiftDefaultLiteral() =>
      defaultValue == null ? null : hwArgbLiteral(defaultValue!);

  @override
  String? codegenKotlinPreviewLiteral() =>
      previewValue == null ? null : kotlinLongLiteral(previewValue!);

  @override
  String? codegenSwiftPreviewLiteral() =>
      previewValue == null ? null : hwArgbLiteral(previewValue!);

  @override
  Set<HWNativeHelper> get renderHelpers =>
      isFixed ? const {} : const {HWNativeHelper.hwColor};

  /// Always throws: a color is not display text.
  ///
  /// Reachable when a color is bound to a text widget, e.g.
  /// `HWText(HWColor('accent'))`.
  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) =>
      throw _notText;

  /// Always throws: a color is not display text.
  @override
  String iosToString({
    required String outerValue,
    required String innerValue,
  }) =>
      throw _notText;

  GeneratorError get _notText => GeneratorError(
        'HWColor cannot be rendered as text. Use '
        '${isFixed ? spellFixedValue(this) : 'the color stored under "$key"'} '
        'in a color slot, such as HWTextStyle(color: ...).',
      );

  @override
  HWColor _merged(HWDataType<dynamic> other) {
    final color = other as HWColor;
    return HWColor(
      key,
      defaultValue: defaultValue ?? color.defaultValue,
      previewValue: previewValue ?? color.previewValue,
    );
  }
}

/// A fixed color defined by an ARGB integer value (e.g. `0xFFFF0000` for Red).
///
/// The target of [HWColor.fixed], which is the spelling to use.
class HWFixedColor extends HWColor {
  /// The ARGB value.
  final int value;

  const HWFixedColor(this.value) : super('');

  @override
  bool get isFixed => true;

  @override
  Object? get _fixedContent => value;

  /// The SwiftUI `Color` literal of [value].
  String get swiftLiteral {
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return 'Color(red: ${r / 255.0}, green: ${g / 255.0}, blue: ${b / 255.0}, '
        'opacity: ${a / 255.0})';
  }

  /// The Compose `Color` literal of [value].
  String get kotlinLiteral {
    final hex = value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'Color(0x$hex)';
  }
}

/// A color that maps to default system semantic colors based on the given role.
class HWDefaultColor extends HWColor {
  final HWColorRole role;

  const HWDefaultColor(this.role) : super('');

  @override
  bool get isFixed => true;

  @override
  Object? get _fixedContent => role;

  /// The SwiftUI color [role] maps to.
  String get swiftLiteral => switch (role) {
        HWColorRole.contentPrimary => 'Color.primary',
        HWColorRole.contentSecondary => 'Color.secondary',
        HWColorRole.contentTertiary => 'Color(.tertiaryLabel)',
        HWColorRole.contentAccent => 'Color.accentColor',
        HWColorRole.defaultBackground => 'Color.clear',
      };

  /// The Glance color [role] maps to, a `ColorProvider`.
  String get kotlinLiteral => switch (role) {
        HWColorRole.contentPrimary => 'GlanceTheme.colors.onSurface',
        HWColorRole.contentSecondary => 'GlanceTheme.colors.onSurfaceVariant',
        HWColorRole.contentTertiary => 'GlanceTheme.colors.outline',
        HWColorRole.contentAccent => 'GlanceTheme.colors.primaryContainer',
        HWColorRole.defaultBackground => 'GlanceTheme.colors.widgetBackground',
      };
}

/// [argb] as the hexadecimal literal a color is written as, which Dart and
/// Swift read the same way.
String hwArgbLiteral(int argb) =>
    '0x${argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';
