import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../util/font_resolver.dart';

/// The first `home_widget` release whose native side can render a custom font.
const String minimumFontHomeWidgetVersion = '0.10.0';

/// Verifies that every font and icon [spec] names can actually be generated for,
/// before a single file is written.
///
/// Three things have to hold: each icon field is a legal set of icons, every
/// icon font is on disk where the schema says it is, and every text font family
/// is declared in a pubspec this project can see. Resolution runs here rather
/// than in the generators so a typo fails the whole command instead of leaving
/// one platform half-generated.
void validateFonts(WidgetSpec spec, Directory projectRoot) {
  _asCliError(spec, () {
    for (final field in spec.iconFields) {
      field.validate();
    }
  });

  // Walking the tree for its icons is itself a check: an icon bound to
  // something that is not an [HWIconData] is rejected right here.
  final variants = _asCliError(spec, () => spec.fontVariants);
  final iconFonts = _asCliError(spec, () => spec.iconCodePoints.keys.toList());
  if (variants.isEmpty && iconFonts.isEmpty) return;

  _requireHomeWidgetFontSupport(spec, projectRoot);

  final fonts = FontResolver(projectRoot);
  for (final variant in variants) {
    fonts.resolveTextFont(variant);
  }
  for (final font in iconFonts) {
    fonts.resolveIconFont(font);
  }
}

/// Runs [check], re-throwing what the generator package rejects as the error
/// type the CLI reports cleanly.
///
/// `home_widget_generator` has a `GeneratorError` of its own, which it does not
/// export — so the CLI cannot catch it by type and would print a stack trace
/// where a one-line message belongs.
T _asCliError<T>(WidgetSpec spec, T Function() check) {
  const prefix = 'GeneratorError: ';
  try {
    return check();
  } on Error catch (error) {
    final text = error.toString();
    if (!text.startsWith(prefix)) rethrow;
    throw GeneratorError(
      'Widget "${spec.data.name}": ${text.substring(prefix.length)}',
    );
  }
}

/// Fails when the app is pinned to a published `home_widget` that predates the
/// font support the generated code calls into.
///
/// Only a hosted dependency is checked: a path, git or workspace dependency is
/// whatever the developer has checked out, and the version in `pubspec.lock`
/// says nothing about it.
void _requireHomeWidgetFontSupport(WidgetSpec spec, Directory projectRoot) {
  final lockFile = File(p.join(projectRoot.path, 'pubspec.lock'));
  if (!lockFile.existsSync()) return;

  final Object? doc;
  try {
    doc = loadYaml(lockFile.readAsStringSync());
  } on YamlException {
    return;
  }
  if (doc is! YamlMap) return;

  final packages = doc['packages'];
  if (packages is! YamlMap) return;

  final homeWidget = packages['home_widget'];
  if (homeWidget is! YamlMap) return;
  if (homeWidget['source'] != 'hosted') return;

  final version = homeWidget['version'];
  if (version is! String) return;
  if (!_isBelow(version, minimumFontHomeWidgetVersion)) return;

  throw GeneratorError(
    'Widget "${spec.data.name}" renders a custom font or an icon, which needs '
    'home_widget $minimumFontHomeWidgetVersion or newer; pubspec.lock resolves '
    'home_widget $version. Raise the home_widget constraint in pubspec.yaml '
    'and run `flutter pub get`.',
  );
}

/// Whether [version] is an older release than [minimum].
///
/// A pre-release of [minimum] counts as new enough: it already carries the
/// native side the generated code calls into.
bool _isBelow(String version, String minimum) {
  final actual = _versionNumbers(version);
  final wanted = _versionNumbers(minimum);
  if (actual == null || wanted == null) return false;

  for (var i = 0; i < 3; i++) {
    if (actual[i] != wanted[i]) return actual[i] < wanted[i];
  }
  return false;
}

List<int>? _versionNumbers(String version) {
  final core = version.split(RegExp('[-+]')).first;
  final parts = core.split('.');
  if (parts.length < 3) return null;
  final numbers = [
    for (final part in parts.take(3)) int.tryParse(part),
  ];
  if (numbers.any((n) => n == null)) return null;
  return numbers.cast<int>();
}
