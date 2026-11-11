import 'dart:io';

import 'package:yaml/yaml.dart';

import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../util/package_config.dart';

/// The first `home_widget` release with the `HomeWidget.launches` and
/// `HomeWidget.initialLaunch` the generated launch helpers call.
const String minimumLaunchHomeWidgetVersion = '0.10.1';

/// Fails when [spec] generates launch helpers and the app is pinned to a
/// published `home_widget` that predates what they call.
void validateLaunchSupport(WidgetSpec spec, Directory projectRoot) {
  if (spec.launchTargets.isEmpty) return;
  try {
    requireHomeWidgetVersion(
      projectRoot,
      minimum: minimumLaunchHomeWidgetVersion,
      feature: 'this widget opens the app with a URL',
    );
  } on GeneratorError catch (error) {
    throw GeneratorError('Widget "${spec.data.name}": ${error.message}');
  }
}

/// The first `home_widget` release with the keyed
/// `HomeWidget.registerInteractivityCallback` and the native entry points the
/// generated buttons call.
// Has to equal the release that carries the `key` parameter of
// `registerInteractivityCallback`. That is only 0.10.1 while the launch
// helpers and the keyed callbacks ship in one release.
const String minimumInteractionHomeWidgetVersion = '0.10.1';

/// Fails when [spec] has buttons and the app is pinned to a published
/// `home_widget` that predates what they call.
void validateInteractionSupport(WidgetSpec spec, Directory projectRoot) {
  if (!spec.hasInteractions) return;
  try {
    requireHomeWidgetVersion(
      projectRoot,
      minimum: minimumInteractionHomeWidgetVersion,
      feature: 'this widget has an HWButton',
    );
  } on GeneratorError catch (error) {
    throw GeneratorError('Widget "${spec.data.name}": ${error.message}');
  }
}

/// Fails when the app is pinned to a published `home_widget` older than
/// [minimum], which [feature] needs.
///
/// Only a hosted dependency is checked: a path, git or workspace dependency is
/// whatever the developer has checked out, and the version in `pubspec.lock`
/// says nothing about it.
void requireHomeWidgetVersion(
  Directory projectRoot, {
  required String minimum,
  required String feature,
}) {
  final lockFile = findFileUpwards(projectRoot, 'pubspec.lock');
  if (lockFile == null) return;

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
  if (!_isBelow(version, minimum)) return;

  throw GeneratorError(
    '$feature, which needs home_widget $minimum or newer; pubspec.lock '
    'resolves home_widget $version. Raise the home_widget constraint in '
    'pubspec.yaml and run `flutter pub get`.',
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
