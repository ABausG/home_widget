/// The font files a generated widget renders text and icons with.
///
/// A widget tree names the ones it needs through `HWWidget.fontVariants` and
/// `HWWidget.iconCodePoints`, and `home_widget_cli` resolves each to a file in
/// the app's `flutter: fonts:` declaration.
///
/// A text font stays where it is: both platforms read it in place out of
/// `flutter_assets`, naming the family and looking the file up in the app's
/// `FontManifest.json` as they render. An icon font is copied next to the
/// generated widget and subset down to the glyphs the schema names, as Flutter
/// tree-shakes those out of `flutter_assets`; the copy is named after
/// [HWIconFont.resourceSuffix].
library;

/// [value] as an Android resource name fragment: lower case, with every run of
/// characters outside `[a-z0-9]` collapsed into a single underscore.
///
/// `Chewy` becomes `chewy`, `Roboto Mono` becomes `roboto_mono` and
/// `MaterialIcons` becomes `materialicons`.
String hwResourceSnakeCase(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');

/// The namespace the icon font resources generated for the widget named
/// [widgetSnakeName] live under.
///
/// Threaded into decoding as `fontResourcePrefix` so a widget's resource names
/// are known by the time any code is emitted, exactly like the string resource
/// prefix behind a constant translation.
String hwFontResourcePrefix(String widgetSnakeName) =>
    'hw_font_$widgetSnakeName';

/// The prefix a resource name falls back to when no widget stamped its own.
const String _fallbackFontResourcePrefix = 'hw_font_home_widget';

/// One font file a generated widget renders text with.
///
/// A family plus the weight and slant a style resolves to, which together pick
/// exactly one file out of a `flutter: fonts:` declaration. The file is never
/// copied and never named: both platforms read it in place out of
/// `flutter_assets`, picking it as they render out of the `FontManifest.json`
/// shipped next to it.
class HWFontVariant {
  /// The family as declared in the pubspec, e.g. `Chewy`.
  final String family;

  /// The package the family is declared in, or null when the app declares it.
  final String? package;

  /// The weight this variant renders at, 100 to 900.
  final int weight;

  /// Whether this variant is the italic file of its family.
  final bool italic;

  const HWFontVariant({
    required this.family,
    required this.weight,
    required this.italic,
    this.package,
  });

  /// The family key Flutter resolves this font under.
  ///
  /// A package's family is namespaced as `packages/<package>/<family>`, which
  /// is both what Flutter registers it as and what the rendered code looks up
  /// in `FontManifest.json`.
  String get flutterFamilyKey =>
      package == null ? family : 'packages/$package/$family';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWFontVariant &&
          family == other.family &&
          package == other.package &&
          weight == other.weight &&
          italic == other.italic;

  @override
  int get hashCode => Object.hash(family, package, weight, italic);

  @override
  String toString() =>
      'HWFontVariant($flutterFamilyKey, $weight, ${italic ? 'italic' : 'normal'})';
}

/// An icon font a generated widget draws glyphs out of.
///
/// The family and package as declared on Flutter's `IconData` — `MaterialIcons`
/// with no package, `CupertinoIcons` from `cupertino_icons`, or whatever an
/// icon package declares.
class HWIconFont {
  /// The family as declared on the icon, e.g. `MaterialIcons`.
  final String family;

  /// The package declaring the family, or null for the app's own.
  final String? package;

  const HWIconFont({required this.family, this.package});

  /// What tells this font apart in a resource name:
  /// `icons_<family>[__<package>]`.
  ///
  /// The package is joined with `__` for the reason [androidResourceName]
  /// gives: over a single underscore a family and a package meet in the middle,
  /// so `Foo` from `bar_baz` and `Foo_bar` from `baz` would name one file.
  String get resourceSuffix {
    final package = this.package;
    final name = 'icons_${hwResourceSnakeCase(family)}';
    return package == null ? name : '${name}__${hwResourceSnakeCase(package)}';
  }

  /// The Android `res/font` resource name for this font in the widget
  /// namespaced by [fontResourcePrefix].
  ///
  /// Joined with `__` rather than `_` so one widget's prefix cannot collide
  /// with the start of a differently-named widget's icon file (e.g. `Weather`
  /// vs. `WeatherIcons`).
  String androidResourceName(String? fontResourcePrefix) =>
      '${fontResourcePrefix ?? _fallbackFontResourcePrefix}__$resourceSuffix';

  /// The name of the file copied into the iOS widget extension, without its
  /// extension.
  ///
  /// Unlike Android's flat resource table, every widget extension is its own
  /// bundle, so the widget's own name is not part of it.
  String get iosResourceName => 'hw_font_$resourceSuffix';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HWIconFont && family == other.family && package == other.package;

  @override
  int get hashCode => Object.hash(family, package);

  @override
  String toString() =>
      'HWIconFont($family${package == null ? '' : ', $package'})';
}
