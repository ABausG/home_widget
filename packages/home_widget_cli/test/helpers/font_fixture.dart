import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A package the fixture's `package_config.json` resolves.
class FixturePackage {
  /// The package name as a dependency writes it.
  final String name;

  /// The package's root directory.
  final String root;

  /// Creates a [FixturePackage].
  const FixturePackage({required this.name, required this.root});
}

/// Writes a project shaped like the parts of a Flutter app the font resolver
/// reads: a `pubspec.yaml` and a `.dart_tool/package_config.json`.
///
/// [pubspecFonts] is the body of the `flutter: fonts:` list, written verbatim,
/// so a test spells its declarations the way a real pubspec does.
void writeFontFixture(
  Directory root, {
  String? pubspecFonts,
  List<FixturePackage> packages = const [],
  String? flutterSdkRoot,
  String? lockedHomeWidgetVersion,
  String homeWidgetSource = 'hosted',
}) {
  final pubspec = StringBuffer('''
name: cli_test

environment:
  sdk: ^3.9.0

flutter:
''');
  if (pubspecFonts != null) {
    pubspec.writeln('  fonts:');
    pubspec.writeln(pubspecFonts);
  } else {
    pubspec.writeln('  uses-material-design: true');
  }
  File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(pubspec.toString());

  if (lockedHomeWidgetVersion != null) {
    File(p.join(root.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  home_widget:
    dependency: "direct main"
    description:
      name: home_widget
      url: "https://pub.dev"
    source: $homeWidgetSource
    version: "$lockedHomeWidgetVersion"
''');
  }

  writePackageConfig(
    root,
    packages: packages,
    flutterSdkRoot: flutterSdkRoot,
  );
}

/// Writes `<root>/.dart_tool/package_config.json` resolving [packages], plus
/// the `flutter` package when [flutterSdkRoot] is given.
void writePackageConfig(
  Directory root, {
  List<FixturePackage> packages = const [],
  String? flutterSdkRoot,
}) {
  final entries = <Map<String, Object?>>[
    for (final package in packages)
      {
        'name': package.name,
        'rootUri': Uri.file(package.root).toString(),
        'packageUri': 'lib/',
      },
    if (flutterSdkRoot != null)
      {
        'name': 'flutter',
        'rootUri':
            Uri.file(p.join(flutterSdkRoot, 'packages', 'flutter')).toString(),
        'packageUri': 'lib/',
      },
  ];

  final file = File(p.join(root.path, '.dart_tool', 'package_config.json'));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'configVersion': 2,
      'packages': entries,
    }),
  );
}

/// Writes a package with its own `flutter: fonts:` section under [root].
///
/// [assets] are written exactly where the declaration puts them, relative to
/// the package root.
Directory writeFontPackage(
  Directory root,
  String name, {
  required String pubspecFonts,
  List<String> assets = const [],
}) {
  final packageRoot = Directory(p.join(root.path, 'packages', name));
  packageRoot.createSync(recursive: true);
  File(p.join(packageRoot.path, 'pubspec.yaml')).writeAsStringSync('''
name: $name

flutter:
  fonts:
$pubspecFonts
''');
  for (final asset in assets) {
    final file =
        File(p.join(packageRoot.path, p.joinAll(p.posix.split(asset))));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(const [0, 1, 2, 3]);
  }
  return packageRoot;
}

/// The Flutter SDK the machine running the tests has, or null when it cannot be
/// found — the icon font sources and the subsetter live inside it.
String? get flutterSdkRootForTests {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && Directory(fromEnv).existsSync()) return fromEnv;

  try {
    final result = Process.runSync('which', ['flutter']);
    if (result.exitCode != 0) return null;
    final binary = (result.stdout as String).trim();
    if (binary.isEmpty) return null;
    final resolved = File(binary).resolveSymbolicLinksSync();
    final root = p.dirname(p.dirname(resolved));
    return Directory(root).existsSync() ? root : null;
  } on ProcessException {
    return null;
  } on FileSystemException {
    return null;
  }
}

/// The `MaterialIcons-Regular.otf` of [sdkRoot], or null when it is not
/// precached.
File? materialIconsFont(String? sdkRoot) {
  if (sdkRoot == null) return null;
  final file = File(
    p.join(
      sdkRoot,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  );
  return file.existsSync() ? file : null;
}

/// Whether the SDK at [sdkRoot] has the `font-subset` binary the CLI shells out
/// to.
bool hasFontSubset(String? sdkRoot) {
  if (sdkRoot == null) return false;
  final engine =
      Directory(p.join(sdkRoot, 'bin', 'cache', 'artifacts', 'engine'));
  if (!engine.existsSync()) return false;
  return engine
      .listSync()
      .whereType<Directory>()
      .any((host) => File(p.join(host.path, 'font-subset')).existsSync());
}
