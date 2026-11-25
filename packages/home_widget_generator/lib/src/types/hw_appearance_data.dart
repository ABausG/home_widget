part of '../types.dart';

/// One of several values, picked by how the system is showing the widget.
///
/// ```dart
/// HWImage(
///   HWAppearanceData(
///     light: HWImageData('logoLight'),
///     dark: HWImageData('logoDark'),
///   ),
/// )
/// ```
///
/// [light] and [dark] follow the widget's color scheme on both platforms.
/// [iosAccented] and [iosVibrant] are iOS only, named after WidgetKit's
/// `widgetRenderingMode`, and take precedence over the color scheme where they
/// are given:
/// - [iosAccented] -- the Home Screen set to Tinted (iOS 18+) or Clear
///   (iOS 26+), WidgetKit's `accented` mode. One value serves both the light
///   and the dark variant of these.
/// - [iosVibrant] -- the Lock Screen and StandBy, WidgetKit's `vibrant` mode.
///
/// Every side is an ordinary value of the same kind — stored, constant, an
/// [HWJson] leaf, an [HWItemData] or an [HWTimedData] — and accepted wherever
/// that kind is: a color slot, an `HWImage`, an `HWIcon`, an `HWText`, an
/// `HWDataExists` or an `HWBoolConditional`. It is a selector, not a stored
/// field: each stored side is a field of its own, saved through its own
/// parameter of the generated `saveData`.
///
/// When the side picked has no value — never saved, deleted, an image that
/// cannot be read — the widget falls back to the side of the color scheme,
/// then to the other scheme's, and then to what it shows for a missing value
/// of that kind. A brand with one logo saves just the [light] one.
///
/// An [HWAppearanceData] is always the outermost wrapper: it cannot sit inside
/// an [HWJson], [HWItemData] or [HWTimedData], inside another one, or in a tap
/// payload.
class HWAppearanceData<T> extends HWDataType<T> {
  /// The value shown in the light color scheme.
  final HWDataType<T> light;

  /// The value shown in the dark color scheme.
  final HWDataType<T> dark;

  /// The value iOS shows on a Home Screen set to Tinted or Clear, or null to
  /// fall back to [light] / [dark] there.
  final HWDataType<T>? iosAccented;

  /// The value iOS shows on the Lock Screen and in StandBy, or null to fall
  /// back to [light] / [dark] there.
  final HWDataType<T>? iosVibrant;

  const HWAppearanceData({
    required this.light,
    required this.dark,
    this.iosAccented,
    this.iosVibrant,
  }) : super('');

  /// Every value given, [light] first, then [dark], [iosAccented] and
  /// [iosVibrant].
  List<HWDataType<T>> get sides => [
        light,
        dark,
        if (iosAccented case final accented?) accented,
        if (iosVibrant case final vibrant?) vibrant,
      ];

  /// The sides, each a field of its own where it is stored.
  @override
  Iterable<HWDataType<dynamic>> get readValues => sides;

  /// Never a field of its own.
  @override
  bool get isDataDependency => false;

  @override
  T? get defaultValue => null;

  @override
  T? get previewValue => null;

  @override
  HWDataType<dynamic> get leaf => light.leaf;

  /// A value of the kind every side holds, stored and without a default: what
  /// a widget renders the picked value as, since the sides apply their own
  /// defaults before one is picked.
  ///
  /// Codegen-internal: consumed by the widgets and by `home_widget_cli`.
  HWDataType<dynamic> get pickedLeaf => switch (leaf) {
        HWColor() => const HWColor(''),
        HWString() => const HWString(''),
        HWInt() => const HWInt(''),
        HWDouble() => const HWDouble(''),
        HWBool() => const HWBool(''),
        HWDateTime() => const HWDateTime(''),
        HWImageData() => const HWImageData(''),
        final other => other,
      };

  @override
  String get dartType => light.dartType;

  @override
  String get kotlinType => light.kotlinType;

  @override
  String get swiftType => light.swiftType;

  @override
  String androidReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) =>
      light.androidReadValue(store: store, key: key, preview: preview);

  @override
  String iosReadValue({
    required String store,
    required String key,
    bool preview = false,
  }) =>
      light.iosReadValue(store: store, key: key, preview: preview);

  /// The picked value, rendered the way [pickedLeaf] renders a missing one.
  @override
  String androidToString({
    required String outerValue,
    required String innerValue,
  }) =>
      pickedLeaf.androidToString(
        outerValue: outerValue,
        innerValue: innerValue,
      );

  @override
  String iosToString({
    required String outerValue,
    required String innerValue,
  }) =>
      pickedLeaf.iosToString(outerValue: outerValue, innerValue: innerValue);

  /// The Swift expression picking a side, an optional, with [value] writing
  /// each side's own expression.
  String swiftPick(String Function(HWDataType<T> side) value) =>
      HWAppearanceChoice.swiftValue(
        light: value(light),
        dark: value(dark),
        accented: iosAccented == null ? null : value(iosAccented!),
        vibrant: iosVibrant == null ? null : value(iosVibrant!),
      );

  /// The Kotlin counterpart of [swiftPick], nullable.
  String kotlinPick(String Function(HWDataType<T> side) value) =>
      HWAppearanceChoice.kotlinValue(light: value(light), dark: value(dark));

  @override
  String swiftAccess(String dataExpr) =>
      swiftPick((side) => side.swiftVariantValue(dataExpr));

  @override
  String kotlinAccess(String dataExpr) =>
      kotlinPick((side) => side.kotlinVariantValue(dataExpr));

  @override
  String swiftReadExpr(String dataExpr) => swiftAccess(dataExpr);

  @override
  String kotlinReadExpr(String dataExpr) => kotlinAccess(dataExpr);

  @override
  Set<String> get swiftViewModifiers =>
      const {HWAppearanceChoice.swiftEnvironmentDeclaration};

  /// Whether Android picks a side when it renders, rather than handing the
  /// launcher a pair to resolve: everything but two constant ARGB colors.
  ///
  /// Codegen-internal: consumed by the widgets and by `home_widget_cli`.
  bool get kotlinPicksAtRender =>
      !(light is HWFixedColor && dark is HWFixedColor);

  @override
  Set<HWNativeHelper> get renderHelpers => {
        ...HWAppearanceChoice.swiftValueHelpers,
        if (kotlinPicksAtRender) ...HWAppearanceChoice.kotlinValueHelpers,
        for (final side in sides) ...side.renderHelpers,
      };

  /// Never: a selector declares no field to fold another declaration into.
  @override
  bool isCompatibleWith(HWDataType<dynamic> other) => false;

  // coverage:ignore-start
  @override
  HWAppearanceData<T> _merged(HWDataType<dynamic> other) => this;
  // coverage:ignore-end

  static const String _hashTag = 'HWAppearanceData';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWAppearanceData &&
          light == other.light &&
          dark == other.dark &&
          iosAccented == other.iosAccented &&
          iosVibrant == other.iosVibrant;

  @override
  int get hashCode =>
      Object.hash(_hashTag, light, dark, iosAccented, iosVibrant);
}
