import 'dart:convert';
import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../generator_error.dart';
import 'logger.dart';
import 'package_config.dart';

/// One file of a `flutter: fonts:` declaration.
class FontFileDeclaration {
  /// The path exactly as the pubspec writes it, relative to the declaring
  /// package.
  final String asset;

  /// The weight the file is declared at, 400 when the declaration omits it.
  final int weight;

  /// Whether the declaration marks the file as the italic one.
  final bool italic;

  /// Creates a [FontFileDeclaration].
  const FontFileDeclaration({
    required this.asset,
    this.weight = 400,
    this.italic = false,
  });

  @override
  String toString() =>
      'FontFileDeclaration($asset, $weight, ${italic ? 'italic' : 'normal'})';
}

/// The `flutter: fonts:` section of one `pubspec.yaml`, family by family.
class PubspecFonts {
  /// Declared families, each mapped to the files it ships.
  final Map<String, List<FontFileDeclaration>> families;

  /// Creates a [PubspecFonts].
  const PubspecFonts(this.families);

  /// Reads the declarations out of the `pubspec.yaml` in [root].
  ///
  /// A missing pubspec, or one declaring no fonts, yields empty declarations —
  /// the caller turns that into an error naming the family it was looking for,
  /// which says more than "no fonts at all".
  factory PubspecFonts.read(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return const PubspecFonts({});

    final Object? doc;
    try {
      doc = loadYaml(pubspec.readAsStringSync());
    } on YamlException {
      return const PubspecFonts({});
    }
    if (doc is! YamlMap) return const PubspecFonts({});

    final flutterSection = doc['flutter'];
    if (flutterSection is! YamlMap) return const PubspecFonts({});

    final fonts = flutterSection['fonts'];
    if (fonts is! YamlList) return const PubspecFonts({});

    final families = <String, List<FontFileDeclaration>>{};
    for (final entry in fonts) {
      if (entry is! YamlMap) continue;
      final family = entry['family'];
      if (family is! String || family.isEmpty) continue;

      final files = entry['fonts'];
      if (files is! YamlList) continue;

      final declarations = families.putIfAbsent(
        family,
        () => <FontFileDeclaration>[],
      );
      for (final file in files) {
        if (file is! YamlMap) continue;
        final asset = file['asset'];
        if (asset is! String || asset.isEmpty) continue;
        final weight = file['weight'];
        declarations.add(
          FontFileDeclaration(
            asset: asset,
            weight: weight is int ? weight : 400,
            italic: file['style'] == 'italic',
          ),
        );
      }
    }
    return PubspecFonts(families);
  }
}

/// One icon font as it sits on disk before it is subset.
class IconFontSource {
  /// The file the glyphs are read out of.
  final File file;

  /// The file's extension, without the dot, which the copy keeps.
  String get extension {
    final ext = p.extension(file.path);
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  /// Creates an [IconFontSource].
  const IconFontSource(this.file);
}

/// Subset output, cached for the whole run so two widgets asking for the same
/// glyphs of the same font run `font-subset` once.
final Map<String, List<int>> _subsetCache = {};

/// Whether the missing-`font-subset` warning has already been logged.
bool _warnedAboutMissingSubsetter = false;

/// Resets the state [FontResolver] keeps for a whole run.
///
/// Only tests need this: within one CLI invocation the cache is what keeps the
/// subsetter from running once per widget.
void resetFontResolverCaches() {
  _subsetCache.clear();
  _warnedAboutMissingSubsetter = false;
}

/// Resolves the font files a generated widget renders with.
///
/// Text fonts resolve to the asset key Flutter registers them under, which both
/// platforms read in place; icon fonts resolve to a file on disk, which is
/// subset and copied next to the generated widget.
class FontResolver {
  /// The Flutter project the fonts are declared in.
  final Directory projectRoot;

  /// Creates a [FontResolver] reading declarations out of [projectRoot].
  FontResolver(this.projectRoot);

  PubspecFonts? _appFonts;
  final Map<String, PubspecFonts?> _packageFonts = {};

  /// The app's own `flutter: fonts:` declarations.
  PubspecFonts get appFonts =>
      _appFonts ??= PubspecFonts.read(projectRoot.path);

  /// The `flutter: fonts:` declarations of [package], or null when the package
  /// cannot be resolved.
  PubspecFonts? packageFonts(String package) => _packageFonts.putIfAbsent(
        package,
        () {
          final resolved = resolvePackage(projectRoot, package);
          if (resolved == null) return null;
          return PubspecFonts.read(resolved.root);
        },
      );

  /// The asset key Flutter registers the file [variant] resolves to under.
  ///
  /// Throws a [GeneratorError] naming the family, the package and the pubspec
  /// section to add when nothing declares it.
  String resolveTextFont(HWFontVariant variant) =>
      _assetKey(variant.package, _declarationFor(variant));

  /// The file on disk [variant] resolves to.
  File resolveTextFontFile(HWFontVariant variant) =>
      _assetFile(variant.package, _declarationFor(variant).asset);

  FontFileDeclaration _declarationFor(HWFontVariant variant) {
    final declarations = _familyFiles(variant.package, variant.family);
    if (declarations == null || declarations.isEmpty) {
      throw GeneratorError(_undeclaredFamilyMessage(variant));
    }
    return _pick(declarations, weight: variant.weight, italic: variant.italic);
  }

  List<FontFileDeclaration>? _familyFiles(String? package, String family) {
    if (package == null) return appFonts.families[family];
    final fonts = packageFonts(package);
    if (fonts == null) {
      throw GeneratorError(
        'The font family "$family" is declared by the package "$package", '
        'which this project does not depend on — or `flutter pub get` has not '
        'run since it was added. Add "$package" to the dependencies of '
        'pubspec.yaml and run `flutter pub get`.',
      );
    }
    return fonts.families[family];
  }

  String _undeclaredFamilyMessage(HWFontVariant variant) {
    final package = variant.package;
    if (package != null) {
      return 'The package "$package" declares no font family '
          '"${variant.family}". Check the spelling of the family and the '
          '"package:" argument, or drop "package:" if the app itself declares '
          'the family.';
    }
    return 'Unknown font family "${variant.family}". Declare it in the '
        '"flutter: fonts:" section of pubspec.yaml so Flutter bundles the '
        'file:\n'
        'flutter:\n'
        '  fonts:\n'
        '    - family: ${variant.family}\n'
        '      fonts:\n'
        '        - asset: assets/fonts/${variant.family}-Regular.ttf';
  }

  /// The file an icon font's glyphs are read out of.
  ///
  /// `MaterialIcons` and `CupertinoIcons` ship with Flutter rather than with the
  /// app, so they are looked up where Flutter keeps them; anything else is a
  /// font like any other and resolves through a `flutter: fonts:` declaration.
  IconFontSource resolveIconFont(HWIconFont font) {
    if (font.package == null && font.family == 'MaterialIcons') {
      final sdk = _requireFlutterSdkRoot(font);
      final file = File(
        p.join(
          sdk,
          'bin',
          'cache',
          'artifacts',
          'material_fonts',
          'MaterialIcons-Regular.otf',
        ),
      );
      if (!file.existsSync()) {
        throw GeneratorError(
          'The Material icon font is not in the Flutter cache at ${file.path}. '
          'Run `flutter precache` and generate again.',
        );
      }
      return IconFontSource(file);
    }

    if (font.package == 'cupertino_icons' && font.family == 'CupertinoIcons') {
      final resolved = resolvePackage(projectRoot, 'cupertino_icons');
      if (resolved == null) {
        throw GeneratorError(
          'The widget uses Cupertino icons, but this project does not depend '
          'on the "cupertino_icons" package — or `flutter pub get` has not run '
          'since it was added. Add it to pubspec.yaml and run '
          '`flutter pub get`.',
        );
      }
      final file =
          File(p.join(resolved.libRoot, 'assets', 'CupertinoIcons.ttf'));
      if (!file.existsSync()) {
        throw GeneratorError(
          'The Cupertino icon font is not where the "cupertino_icons" package '
          'usually keeps it (${file.path}).',
        );
      }
      return IconFontSource(file);
    }

    final declarations = _familyFiles(font.package, font.family);
    if (declarations == null || declarations.isEmpty) {
      throw GeneratorError(
        'Unknown icon font family "${font.family}"'
        '${font.package == null ? '' : ' of package "${font.package}"'}. '
        'An icon font has to be declared in the "flutter: fonts:" section of '
        'the pubspec that ships it, the way every icon package declares it.',
      );
    }
    final file = _assetFile(font.package, declarations.first.asset);
    if (!file.existsSync()) {
      throw GeneratorError(
        'The icon font "${font.family}" is declared as '
        '"${declarations.first.asset}", which does not exist at ${file.path}.',
      );
    }
    return IconFontSource(file);
  }

  String _requireFlutterSdkRoot(HWIconFont font) {
    final sdk = resolveFlutterSdkRoot(projectRoot);
    if (sdk == null) {
      throw GeneratorError(
        'Could not find the Flutter SDK the icon font "${font.family}" ships '
        'with: ${p.join(projectRoot.path, '.dart_tool', 'package_config.json')}'
        ' does not resolve the "flutter" package. Run `flutter pub get` and '
        'generate again.',
      );
    }
    return sdk;
  }

  /// [asset] as Flutter registers it: a package's file is namespaced, the app's
  /// own is the path it was declared as.
  String _assetKey(String? package, FontFileDeclaration declaration) {
    final asset = declaration.asset;
    if (package == null || asset.startsWith('packages/')) return asset;
    return 'packages/$package/$asset';
  }

  /// The file [asset] names, which for a package sits under its `lib/`.
  File _assetFile(String? package, String asset) {
    final relative = asset.startsWith('packages/')
        ? asset.split('/').skip(2).join('/')
        : asset;
    final segments = p.posix.split(relative);
    if (package == null) {
      return File(p.join(projectRoot.path, p.joinAll(segments)));
    }
    final resolved = resolvePackage(projectRoot, package);
    if (resolved == null) {
      throw GeneratorError(
        'Could not resolve the package "$package" that declares "$asset". Run '
        '`flutter pub get` and generate again.',
      );
    }
    return File(p.join(resolved.libRoot, p.joinAll(segments)));
  }

  /// The one file of [candidates] that renders [weight] and [italic] best.
  ///
  /// The same rule Flutter applies at runtime: an exact weight wins, otherwise
  /// the nearest one, looking down from a light target and up from a heavy one.
  /// A file of the right slant always beats one of the wrong slant, however far
  /// its weight is off — a synthetic slant is a smaller lie than an upright
  /// glyph where an italic was asked for.
  static FontFileDeclaration _pick(
    List<FontFileDeclaration> candidates, {
    required int weight,
    required bool italic,
  }) {
    final matchingStyle = candidates.where((c) => c.italic == italic).toList();
    final pool = matchingStyle.isEmpty ? candidates : matchingStyle;

    for (final candidate in pool) {
      if (candidate.weight == weight) return candidate;
    }

    final lighter = pool.where((c) => c.weight < weight).toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final heavier = pool.where((c) => c.weight > weight).toList()
      ..sort((a, b) => a.weight.compareTo(b.weight));

    // CSS's rule, which Flutter follows: a light target reaches for the lighter
    // files first, a bold one for the bolder files.
    final ordered =
        weight <= 400 ? [...lighter, ...heavier] : [...heavier, ...lighter];
    return ordered.first;
  }

  /// [source] reduced to [codePoints], or its whole bytes when the SDK's
  /// subsetter is not available.
  ///
  /// Flutter tree-shakes icon fonts out of `flutter_assets`, so a widget carries
  /// its own copy — and a copy of a full icon font is megabytes for the handful
  /// of glyphs a schema names.
  Future<List<int>> subsetIconFont(
    IconFontSource source,
    Set<int> codePoints,
  ) async {
    final sorted = codePoints.toList()..sort();
    final cacheKey = '${source.file.path}|${sorted.join(',')}';
    final cached = _subsetCache[cacheKey];
    if (cached != null) return cached;

    final binary = _fontSubsetBinary();
    if (binary == null) {
      if (!_warnedAboutMissingSubsetter) {
        _warnedAboutMissingSubsetter = true;
        logger.warn(
          'Warning: the Flutter SDK\'s font-subset tool was not found, so icon '
          'fonts are copied whole. Run `flutter precache` to shrink them.',
        );
      }
      final whole = await source.file.readAsBytes();
      return _subsetCache[cacheKey] = whole;
    }

    final tempDir = await Directory.systemTemp.createTemp('hw_font_subset');
    try {
      final extension = p.extension(source.file.path);
      final out = File(p.join(tempDir.path, 'subset$extension'));
      final process = await Process.start(binary, [out.path, source.file.path]);
      // Both pipes are drained while the subsetter runs: a full one blocks it,
      // and it writes the reason a font was rejected to stderr.
      final stderrOutput = process.stderr.transform(utf8.decoder).join();
      final stdoutDrain = process.stdout.drain<void>();
      // The glyphs, one `0x` codepoint per line, which is the only input
      // `font-subset` takes.
      process.stdin.write(
        sorted.map((c) => '0x${c.toRadixString(16)}').join('\n'),
      );
      process.stdin.writeln();
      await process.stdin.flush();
      await process.stdin.close();

      final exitCode = await process.exitCode;
      await stdoutDrain;
      final failure = (await stderrOutput).trim();
      if (exitCode != 0 || !out.existsSync()) {
        throw GeneratorError(
          'Subsetting the icon font ${p.basename(source.file.path)} failed '
          '(exit code $exitCode): $failure',
        );
      }
      return _subsetCache[cacheKey] = await out.readAsBytes();
    } finally {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    }
  }

  /// The SDK's `font-subset`, or null when the engine artifacts are not
  /// downloaded.
  ///
  /// The host directory under `engine/` is whatever the SDK happens to have
  /// precached — `darwin-x64` even on an arm64 Mac — so it is globbed rather
  /// than named.
  String? _fontSubsetBinary() {
    final sdk = resolveFlutterSdkRoot(projectRoot);
    if (sdk == null) return null;
    final engineDir =
        Directory(p.join(sdk, 'bin', 'cache', 'artifacts', 'engine'));
    if (!engineDir.existsSync()) return null;

    final hosts = engineDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final host in hosts) {
      final binary = File(p.join(host.path, 'font-subset'));
      if (binary.existsSync()) return binary.path;
      final windows = File(p.join(host.path, 'font-subset.exe'));
      if (windows.existsSync()) return windows.path;
    }
    return null;
  }
}
