part of 'hw_widget.dart';

/// Renders one of several layouts, picked by how the system is showing the
/// widget.
///
/// ```dart
/// HWAppearanceAdaptive(
///   light: HWRow(children: [logo, title]),
///   dark: HWRow(children: [logo, title]),
///   iosAccented: HWColumn(children: [title]),
///   iosVibrant: HWText(HWString('title')),
/// )
/// ```
///
/// The slots and the order they are picked in are those of an
/// [HWAppearanceData]: [iosAccented] on a Home Screen set to Tinted or Clear
/// and [iosVibrant] on the Lock Screen and in StandBy, where they are given
/// and only on iOS, and otherwise [light] or [dark] by the color scheme. A
/// slot is a layout, not a value, so nothing falls back to another slot.
///
/// The data fields every slot declares are fields of the widget, as with
/// [HWSizeAdaptive] and [HWAdaptive], either of which may sit inside a slot or
/// around this widget.
class HWAppearanceAdaptive extends HWWidget {
  /// The layout rendered in the light color scheme.
  final HWWidget light;

  /// The layout rendered in the dark color scheme.
  final HWWidget dark;

  /// The layout iOS renders on a Home Screen set to Tinted or Clear, or null
  /// to render [light] or [dark] there.
  final HWWidget? iosAccented;

  /// The layout iOS renders on the Lock Screen and in StandBy, or null to
  /// render [light] or [dark] there.
  final HWWidget? iosVibrant;

  const HWAppearanceAdaptive({
    required this.light,
    required this.dark,
    this.iosAccented,
    this.iosVibrant,
  });

  static HWAppearanceAdaptive fromDartObject(
    DartObject obj,
    WidgetValueDecoder decoder,
  ) {
    HWWidget? slot(String name) {
      final field = WidgetValueDecoder.getField(obj, name);
      if (field == null || field.isNull) return null;
      return decoder.decodeRecursive(field);
    }

    final light = slot('light');
    final dark = slot('dark');
    if (light == null || dark == null) {
      // coverage:ignore-start
      throw GeneratorError('HWAppearanceAdaptive requires light and dark');
      // coverage:ignore-end
    }
    return HWAppearanceAdaptive(
      light: light,
      dark: dark,
      iosAccented: slot('iosAccented'),
      iosVibrant: slot('iosVibrant'),
    );
  }

  /// The layouts iOS picks between, [light] and [dark] first.
  List<HWWidget> get _swiftSlots => [
        light,
        dark,
        if (iosAccented case final accented?) accented,
        if (iosVibrant case final vibrant?) vibrant,
      ];

  /// This widget picking between the slots [slots] holds, in [_swiftSlots]
  /// order.
  HWAppearanceAdaptive _withSlots(List<HWWidget> slots) {
    var index = 2;
    return HWAppearanceAdaptive(
      light: slots[0],
      dark: slots[1],
      iosAccented: iosAccented == null ? null : slots[index++],
      iosVibrant: iosVibrant == null ? null : slots[index],
    );
  }

  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        for (final slot in _swiftSlots) ...slot.dataDependencies,
      };

  @override
  List<HWWidget> get childWidgets => _swiftSlots;

  /// Android has no rendering modes, so it only ever renders [light] or
  /// [dark].
  @override
  List<HWWidget> get androidChildWidgets => [light, dark];

  @override
  Set<HWNativeHelper> get renderHelpers => HWAppearanceChoice.layoutHelpers;

  @override
  Set<String> get kotlinImports => kotlinImportsIn(null);

  /// Whichever slot renders is emitted where this widget sits, so both are
  /// laid out by the enclosing layout.
  @override
  Set<String> kotlinImportsIn(HWAxis? enclosingLinearAxis) => {
        ...light.kotlinImportsIn(enclosingLinearAxis),
        ...dark.kotlinImportsIn(enclosingLinearAxis),
      };

  @override
  Set<String> get swiftViewModifiers => {
        HWAppearanceChoice.swiftEnvironmentDeclaration,
        for (final slot in _swiftSlots) ...slot.swiftViewModifiers,
      };

  @override
  String get swiftFrameAlignment => _sharedSwiftFrameAlignment(_swiftSlots);

  @override
  bool get swiftClipsFrame => _swiftSlots.any((slot) => slot.swiftClipsFrame);

  /// On SwiftUI each slot sized on its own, while any decorates; Glance
  /// already sizes the slot it picks.
  @override
  HWWidget? _sizedInside(
    double? width,
    double? height, {
    required bool glance,
  }) {
    if (glance) return null;
    if (_swiftSlots.every(
      (slot) => slot._sizedInside(width, height, glance: false) == null,
    )) {
      return null;
    }
    return _withSlots([
      for (final slot in _swiftSlots)
        HWSizedBox(width: width, height: height, child: slot),
    ]);
  }

  /// Each Android slot on its own, while either draws a picture.
  @override
  HWWidget? _kotlinFilling({required bool width, required bool height}) {
    HWWidget? filling(HWWidget slot) =>
        slot._sizedInside(
          width ? double.infinity : null,
          height ? double.infinity : null,
          glance: true,
        ) ??
        slot._kotlinFilling(width: width, height: height);
    final lightFilling = filling(light);
    final darkFilling = filling(dark);
    if (lightFilling == null && darkFilling == null) return null;
    return HWAppearanceAdaptive(
      light: lightFilling ?? light,
      dark: darkFilling ?? dark,
      iosAccented: iosAccented,
      iosVibrant: iosVibrant,
    );
  }

  /// The slot taken is only known at render time, so a stack lays out each
  /// of them by what it needs itself.
  @override
  List<HWWidget> _kotlinChoices(HWEmitContext? context) => [light, dark];

  @override
  String _kotlinChoice(
    int indent, {
    required String dataExpr,
    required HWEmitContext? context,
    required String Function(HWWidget widget, int indent) emit,
  }) =>
      HWAppearanceChoice.kotlinLayout(
        indent,
        light: emit(light, indent + 1),
        dark: emit(dark, indent + 1),
      );

  /// The text of whichever slot renders, read through the same condition the
  /// emitted `if` goes by.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) {
    final lightText = light.kotlinBaselineText(context);
    final darkText = dark.kotlinBaselineText(context);
    if (lightText == null || darkText == null) return null;
    return HWKotlinBaselineText(
      ascent: (dataExpr) => 'if (${HWAppearanceChoice.kotlinDarkCondition}) '
          '${darkText.ascent(dataExpr)} else ${lightText.ascent(dataExpr)}',
      isBitmap: lightText.isBitmap || darkText.isBitmap,
      readsItem: lightText.readsItem || darkText.readsItem,
      kotlinImports: {...lightText.kotlinImports, ...darkText.kotlinImports},
      conflict: lightText.conflict ?? darkText.conflict,
    );
  }

  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    String emit(HWWidget slot) =>
        slot.toSwift(indent + 1, dataExpr: dataExpr, context: context);
    return HWAppearanceChoice.swiftLayout(
      indent,
      light: emit(light),
      dark: emit(dark),
      accented: iosAccented == null ? null : emit(iosAccented!),
      vibrant: iosVibrant == null ? null : emit(iosVibrant!),
    );
  }

  @override
  String toKotlin(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) =>
      _kotlinChoice(
        indent,
        dataExpr: dataExpr,
        context: context,
        emit: (widget, indent) =>
            widget.toKotlin(indent, dataExpr: dataExpr, context: context),
      );
}
