import 'native_helpers.dart';

/// How generated code picks between the variants of an `HWAppearanceData` or
/// an `HWAppearanceAdaptive`.
///
/// Every appearance choice the generator emits goes through here, so how a
/// platform decides between them is written down in one place.
///
/// iOS picks through the SwiftUI environment, which follows every switch.
/// Android re-runs nothing on a switch: the launcher only inflates what it
/// holds again under the new configuration. Colors are handed to it as a
/// day/night `ColorProvider` ([kotlinColor]) and images and icons as a
/// `RemoteViews` icon pair ([kotlinPair]), which it switches between itself.
/// Text, a branch or a layout is picked when the widget renders
/// ([kotlinValue], [kotlinLayout]) and changes at its next update.
///
/// Codegen-internal: consumed by the widgets and by `home_widget_cli`, not by
/// app code.
abstract final class HWAppearanceChoice {
  /// The name of the `EnvironmentValues` the Swift choices read.
  static const String swiftEnvironment = 'hwEnvironment';

  /// The declaration the generated SwiftUI view carries for
  /// [swiftEnvironment].
  static const String swiftEnvironmentDeclaration =
      '@Environment(\\.self) var $swiftEnvironment';

  /// The helpers a Swift value choice calls.
  static const Set<HWNativeHelper> swiftValueHelpers = {
    HWNativeHelper.hwAppearance,
  };

  /// The helpers a Kotlin value choice calls.
  static const Set<HWNativeHelper> kotlinValueHelpers = {
    HWNativeHelper.hwDayNight,
  };

  /// The helpers picking a value calls on either platform, whatever kind of
  /// value it is: [swiftValueHelpers] and [kotlinValueHelpers].
  static const Set<HWNativeHelper> pickHelpers = {
    ...swiftValueHelpers,
    ...kotlinValueHelpers,
  };

  /// The helpers a Swift or Kotlin layout choice calls, [accented] and
  /// [vibrant] telling whether it has a variant for that rendering mode.
  static Set<HWNativeHelper> layoutHelpers({
    required bool accented,
    required bool vibrant,
  }) =>
      {
        if (accented) HWNativeHelper.hwIsAccented,
        if (vibrant) HWNativeHelper.hwIsVibrant,
        HWNativeHelper.hwIsNight,
      };

  /// Swift expression for the variant shown, an optional of the variants'
  /// type, each variant an expression evaluated only when it is reached.
  ///
  /// [accented] and [vibrant] are the variants for WidgetKit's accented and
  /// vibrant rendering modes, or null where the value has none.
  static String swiftValue({
    required String light,
    required String dark,
    String? accented,
    String? vibrant,
  }) {
    final arguments = [
      swiftEnvironment,
      'light: $light',
      'dark: $dark',
      if (accented != null) 'accented: $accented',
      if (vibrant != null) 'vibrant: $vibrant',
    ];
    return '${HWNativeHelper.hwAppearance.name}(${arguments.join(', ')})';
  }

  /// Kotlin expression for the variant shown, nullable, each variant an
  /// expression evaluated only when it is reached.
  ///
  /// It reads the night mode of `context` when the widget renders. Android has
  /// no rendering modes: the iOS variants never reach it.
  static String kotlinValue({required String light, required String dark}) =>
      '${HWNativeHelper.hwDayNight.name}(context, { $light }, { $dark })';

  /// Kotlin `HomeWidgetAppearance.DayNight` of the values shown in either
  /// appearance, nullable, [light] and [dark] each a nullable expression.
  ///
  /// Where the launcher switches by itself it holds both values, each falling
  /// back to the other; elsewhere both are the one [kotlinValue] picks.
  static String kotlinPair({required String light, required String dark}) =>
      'HomeWidgetAppearance.pick(context, { $light }, { $dark })';

  /// The Kotlin imports [kotlinPair] needs.
  static const Set<String> kotlinPairImports = {
    'import es.antonborri.home_widget.HomeWidgetAppearance',
  };

  /// Kotlin `ColorProvider` for two constant colors, [light] and [dark] each a
  /// Compose `Color` expression.
  ///
  /// The launcher resolves it against the night mode itself, so it calls no
  /// helper.
  static String kotlinColorPair({
    required String light,
    required String dark,
  }) =>
      'ColorProvider(day = $light, night = $dark)';

  /// The Kotlin imports [kotlinColorPair] needs.
  static const Set<String> kotlinColorPairImports = {
    'import androidx.compose.ui.graphics.Color',
    'import androidx.glance.color.ColorProvider',
  };

  /// Kotlin `ColorProvider` of the colors [light] and [dark] resolve to, each
  /// a nullable `ColorProvider` expression, which the launcher switches
  /// between itself; nullable, null while neither has a value.
  static String kotlinColor({required String light, required String dark}) =>
      '${HWNativeHelper.hwAppearanceColor.name}(context, $light, $dark)';

  /// The helpers [kotlinColor] calls.
  static const Set<HWNativeHelper> kotlinColorHelpers = {
    HWNativeHelper.hwAppearanceColor,
  };

  /// The helpers a Kotlin image or icon pair calls.
  static const Set<HWNativeHelper> kotlinImageHelpers = {
    HWNativeHelper.hwAppearanceImage,
  };

  /// The SwiftUI statement rendering one of the variants of a layout,
  /// [indent] levels deep.
  ///
  /// Each variant is its own emitted view at `indent + 1`; [accented] and
  /// [vibrant] are null where the layout has none for that mode.
  static String swiftLayout(
    int indent, {
    required String light,
    required String dark,
    String? accented,
    String? vibrant,
  }) {
    final pad = '    ' * indent;
    final branches = [
      if (accented != null)
        ('${HWNativeHelper.hwIsAccented.name}($swiftEnvironment)', accented),
      if (vibrant != null)
        ('${HWNativeHelper.hwIsVibrant.name}($swiftEnvironment)', vibrant),
      ('$swiftEnvironment.colorScheme == .dark', dark),
    ];
    final buffer = StringBuffer(pad);
    for (final (index, (condition, body)) in branches.indexed) {
      buffer.writeln('${index == 0 ? 'if' : '} else if'} $condition {');
      buffer.writeln(body);
      buffer.write(pad);
    }
    buffer.writeln('} else {');
    buffer.writeln(light);
    buffer.write('$pad}');
    return buffer.toString();
  }

  /// The Glance code rendering one of the variants of a layout, [indent]
  /// levels deep, each variant its own emitted code at `indent + 1`.
  ///
  /// Like [kotlinValue] it reads the night mode of `context` when the widget
  /// renders.
  static String kotlinLayout(
    int indent, {
    required String light,
    required String dark,
  }) {
    final pad = '    ' * indent;
    return '''
${pad}if ($kotlinDarkCondition) {
$dark
$pad} else {
$light
$pad}''';
  }

  /// The Kotlin condition under which a layout renders its dark variant.
  static const String kotlinDarkCondition = 'hwIsNight(context)';
}
