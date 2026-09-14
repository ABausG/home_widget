import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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

/// Parsed `package_config.json` contents, kept per project root so a run that
/// resolves dozens of packages reads and decodes the file once.
final Map<String, Map<String, ResolvedPackage>?> _configCache = {};

/// Forgets the parsed `package_config.json` of every project root.
///
/// Called whenever the run itself may have changed the config — adding a
/// dependency rewrites it — so a later resolve does not answer out of what was
/// read before.
void resetPackageConfigCache() => _configCache.clear();

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
  final key = p.normalize(projectRoot.absolute.path);
  final packages = _configCache.containsKey(key)
      ? _configCache[key]
      : _configCache[key] = _readPackageConfig(projectRoot);
  return packages?[package];
}

Map<String, ResolvedPackage>? _readPackageConfig(Directory projectRoot) {
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

  // `file:` URIs in package_config.json may be relative to the config file.
  final base = Uri.file(configFile.absolute.path);
  final resolved = <String, ResolvedPackage>{};

  for (final entry in packages) {
    if (entry is! Map<String, dynamic>) continue;
    final name = entry['name'];
    if (name is! String) continue;

    final rootUri = entry['rootUri'];
    if (rootUri is! String) continue;

    final resolvedRoot = base.resolve(_ensureTrailingSlash(rootUri));
    if (resolvedRoot.scheme != 'file') continue;

    final packageUri = entry['packageUri'];
    final libUri = resolvedRoot.resolve(
      _ensureTrailingSlash(packageUri is String ? packageUri : 'lib/'),
    );
    resolved[name] = ResolvedPackage(
      root: p.fromUri(resolvedRoot),
      libRoot: p.fromUri(libUri),
    );
  }

  return resolved;
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

/// The `flutter:` section of the `pubspec.yaml` in [root], or null when there is
/// no pubspec, it does not parse, or it declares no `flutter:` map.
YamlMap? readFlutterSection(String root) {
  final pubspec = File(p.join(root, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;

  final Object? doc;
  try {
    doc = loadYaml(pubspec.readAsStringSync());
  } on YamlException {
    return null;
  }
  if (doc is! YamlMap) return null;

  final flutterSection = doc['flutter'];
  return flutterSection is YamlMap ? flutterSection : null;
}

String _ensureTrailingSlash(String uri) => uri.endsWith('/') ? uri : '$uri/';

/// The nearest `.dart_tool/package_config.json` at or above [from].
File? _findPackageConfig(Directory from) =>
    findFileUpwards(from, p.join('.dart_tool', 'package_config.json'));

/// The nearest [relativePath] at or above [from], or null when no directory of
/// the chain holds it.
///
/// A pub workspace keeps the files the tools generate at the workspace root
/// rather than next to the package's own `pubspec.yaml`, so anything looked up
/// by convention is looked up the whole way up.
File? findFileUpwards(Directory from, String relativePath) {
  var current = Directory(p.normalize(from.absolute.path));
  while (true) {
    final candidate = File(p.join(current.path, relativePath));
    if (candidate.existsSync()) return candidate;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}
