import 'dart:convert';
import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../generator_error.dart';
import '../models/widget_spec.dart';

/// Verifies that every `HWImage.asset` / `HWImageData.asset` in [spec] points at
/// an asset that will actually be bundled, so a typo fails at generate time
/// instead of silently rendering nothing on the home screen.
///
/// App assets (no package) must exist on disk under [projectRoot] **and** be
/// covered by the `flutter: assets:` section of the app's `pubspec.yaml`.
///
/// Package assets -- written either as `HWImageData.asset(path, package: 'pkg')`
/// or as the manual `packages/pkg/path` spelling -- are resolved through
/// `<projectRoot>/.dart_tool/package_config.json` and only checked for
/// existence; declaring them is the dependency author's job. When the package
/// config is missing or does not list the package (e.g. `pub get` has not run
/// yet) the field is skipped silently rather than failing generation.
///
/// Runtime images are never validated: their bytes only exist at runtime.
void validateAssets(WidgetSpec spec, Directory projectRoot) {
  final assetFields = spec.assetImageFields;
  if (assetFields.isEmpty) return;

  _PubspecAssets? appAssets;

  for (final image in assetFields) {
    final reference = _AssetReference.from(image);

    if (reference.package != null) {
      _validatePackageAsset(spec, reference, projectRoot);
      continue;
    }

    appAssets ??= _PubspecAssets.read(projectRoot);
    _validateAppAsset(spec, reference, projectRoot, appAssets);
  }
}

/// An asset image split into its owning package (if any) and the path relative
/// to that package's asset root.
class _AssetReference {
  /// The package that owns the asset, or null for an app asset.
  final String? package;

  /// The path relative to the owning package (no `packages/<pkg>/` prefix).
  final String path;

  /// The asset key as it appears to Flutter, used in error messages.
  final String effectiveKey;

  const _AssetReference({
    required this.package,
    required this.path,
    required this.effectiveKey,
  });

  /// Splits [image] into package and package-relative path.
  ///
  /// An explicit `package:` wins; otherwise a bare `packages/<pkg>/<rest>`
  /// path is treated as the manual spelling of the same thing. Anything else
  /// is an app asset.
  factory _AssetReference.from(HWImageData image) {
    final effectiveKey = image.effectiveAssetKey!;
    final package = image.package;
    if (package != null) {
      return _AssetReference(
        package: package,
        path: image.assetPath!,
        effectiveKey: effectiveKey,
      );
    }

    const prefix = 'packages/';
    if (effectiveKey.startsWith(prefix)) {
      final rest = effectiveKey.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash > 0 && slash < rest.length - 1) {
        return _AssetReference(
          package: rest.substring(0, slash),
          path: rest.substring(slash + 1),
          effectiveKey: effectiveKey,
        );
      }
    }

    return _AssetReference(
      package: null,
      path: effectiveKey,
      effectiveKey: effectiveKey,
    );
  }
}

void _validateAppAsset(
  WidgetSpec spec,
  _AssetReference reference,
  Directory projectRoot,
  _PubspecAssets appAssets,
) {
  final file = File(p.join(projectRoot.path, reference.path));
  if (!file.existsSync()) {
    throw GeneratorError(
      'Missing asset for widget "${spec.className}": '
      '"${reference.path}" does not exist at ${file.path}. '
      'Create the file or fix the path in HWImage.asset(...).',
    );
  }

  if (!appAssets.covers(reference.path)) {
    throw GeneratorError(
      'Undeclared asset for widget "${spec.className}": '
      '"${reference.path}" is not listed in the "flutter: assets:" section of '
      'pubspec.yaml. Add it so Flutter bundles the asset:\n'
      'flutter:\n'
      '  assets:\n'
      '    - ${reference.path}',
    );
  }
}

void _validatePackageAsset(
  WidgetSpec spec,
  _AssetReference reference,
  Directory projectRoot,
) {
  final packageRoot = _resolvePackageAssetRoot(projectRoot, reference.package!);
  // `pub get` may not have run yet, or the package is not a dependency of this
  // project: skip rather than block generation.
  if (packageRoot == null) return;

  final file = File(p.join(packageRoot, reference.path));
  if (!file.existsSync()) {
    throw GeneratorError(
      'Missing package asset for widget "${spec.className}": '
      '"${reference.effectiveKey}" does not exist at ${file.path}. '
      'Package assets live under the dependency\'s lib/ directory.',
    );
  }
}

/// Resolves the directory that `packages/<package>/...` asset paths are
/// relative to, i.e. the package's `lib/` folder.
///
/// Returns null when `.dart_tool/package_config.json` is absent, unreadable, or
/// does not contain [package].
String? _resolvePackageAssetRoot(Directory projectRoot, String package) {
  final configFile =
      File(p.join(projectRoot.path, '.dart_tool', 'package_config.json'));
  if (!configFile.existsSync()) return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(configFile.readAsStringSync());
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final packages = decoded['packages'];
  if (packages is! List) return null;

  for (final entry in packages) {
    if (entry is! Map<String, dynamic>) continue;
    if (entry['name'] != package) continue;

    final rootUri = entry['rootUri'];
    if (rootUri is! String) return null;

    // `file:` URIs in package_config.json may be relative to the config file.
    final base = Uri.file(configFile.absolute.path);
    final resolvedRoot = base.resolve(_ensureTrailingSlash(rootUri));
    if (resolvedRoot.scheme != 'file') return null;

    final packageUri = entry['packageUri'];
    final libUri = resolvedRoot.resolve(
      _ensureTrailingSlash(packageUri is String ? packageUri : 'lib/'),
    );
    return p.fromUri(libUri);
  }

  return null;
}

String _ensureTrailingSlash(String uri) => uri.endsWith('/') ? uri : '$uri/';

/// The `flutter: assets:` declarations of the app's `pubspec.yaml`.
class _PubspecAssets {
  /// Declared entries that name a single file.
  final Set<String> files;

  /// Declared entries ending in `/`, normalized without the trailing slash.
  final Set<String> directories;

  const _PubspecAssets({required this.files, required this.directories});

  /// Reads the declarations from `<projectRoot>/pubspec.yaml`.
  ///
  /// A missing pubspec, or one without a `flutter: assets:` list, yields empty
  /// declarations, which makes every asset report as undeclared.
  factory _PubspecAssets.read(Directory projectRoot) {
    final files = <String>{};
    final directories = <String>{};

    final pubspec = File(p.join(projectRoot.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return _PubspecAssets(files: files, directories: directories);
    }

    final Object? doc;
    try {
      doc = loadYaml(pubspec.readAsStringSync());
    } on YamlException {
      return _PubspecAssets(files: files, directories: directories);
    }
    if (doc is! YamlMap) {
      return _PubspecAssets(files: files, directories: directories);
    }

    final flutterSection = doc['flutter'];
    if (flutterSection is! YamlMap) {
      return _PubspecAssets(files: files, directories: directories);
    }

    final assets = flutterSection['assets'];
    if (assets is! YamlList) {
      return _PubspecAssets(files: files, directories: directories);
    }

    for (final entry in assets) {
      // Flutter accepts both `- assets/logo.png` and the map form used for
      // flavors / transformers (`- path: assets/logo.png`).
      final value = entry is YamlMap ? entry['path'] : entry;
      if (value is! String || value.isEmpty) continue;
      if (value.endsWith('/')) {
        directories.add(p.normalize(value.substring(0, value.length - 1)));
      } else {
        files.add(p.normalize(value));
      }
    }

    return _PubspecAssets(files: files, directories: directories);
  }

  /// Whether [assetPath] is bundled by one of the declarations.
  ///
  /// Matches Flutter's semantics: a file entry matches exactly, and a directory
  /// entry covers the files directly inside it but not its subdirectories.
  bool covers(String assetPath) {
    final normalized = p.normalize(assetPath);
    if (files.contains(normalized)) return true;
    return directories.contains(p.normalize(p.dirname(normalized)));
  }
}
