import 'native_helpers.dart';

/// How generated code picks between the variants of an `HWAppearanceData` or
/// an `HWAppearanceAdaptive`.
///
/// Every appearance choice the generator emits goes through here, so how a
/// platform decides between them is written down in one place.
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

  /// The helpers a Swift or Kotlin layout choice calls.
  static const Set<HWNativeHelper> layoutHelpers = {
    HWNativeHelper.hwIsAccented,
    HWNativeHelper.hwIsVibrant,
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
  /// Android has no rendering modes: the iOS variants never reach it.
  static String kotlinValue({required String light, required String dark}) =>
      '${HWNativeHelper.hwDayNight.name}(context, { $light }, { $dark })';

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
