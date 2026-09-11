import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Where a package a project depends on lives on disk.
class ResolvedPackage {
  /// The package's own root, i.e. the directory holding its `pubspec.yaml`.
  final String root;

  /// The directory `packages/<name>/...` asset keys are relative to, i.e. the
  /// package's `lib/`.
  final String libRoot;

  /// Creates a [ResolvedPackage].
  const ResolvedPackage({required this.root, required this.libRoot});
}

/// Resolves [package] through the project's `.dart_tool/package_config.json`.
///
/// In a pub workspace the config sits at the workspace root rather than next to
/// the project's own `pubspec.yaml`, so the lookup walks up the directory chain
/// the way the Dart tools themselves do.
///
/// Returns null when the package config is absent, unreadable, or does not list
/// [package] — `pub get` may simply not have run yet, which callers treat as
/// "cannot tell" rather than as an error.
ResolvedPackage? resolvePackage(Directory projectRoot, String package) {
  final configFile = _findPackageConfig(projectRoot);
  if (configFile == null) return null;

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
    return ResolvedPackage(
      root: p.fromUri(resolvedRoot),
      libRoot: p.fromUri(libUri),
    );
  }

  return null;
}

/// The Flutter SDK the project resolves against, or null when it cannot be
/// told.
///
/// The `flutter` package always sits at `<sdk>/packages/flutter`, so the SDK
/// root is two levels above the package root the config points at.
String? resolveFlutterSdkRoot(Directory projectRoot) {
  final flutter = resolvePackage(projectRoot, 'flutter');
  if (flutter == null) return null;
  return p.dirname(p.dirname(p.normalize(flutter.root)));
}

String _ensureTrailingSlash(String uri) => uri.endsWith('/') ? uri : '$uri/';

/// The nearest `.dart_tool/package_config.json` at or above [from].
File? _findPackageConfig(Directory from) {
  var current = Directory(p.normalize(from.absolute.path));
  while (true) {
    final candidate =
        File(p.join(current.path, '.dart_tool', 'package_config.json'));
    if (candidate.existsSync()) return candidate;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}
