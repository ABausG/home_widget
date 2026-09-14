import 'dart:io';

import 'package:home_widget_cli/src/util/font_resolver.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hw_font_resolver');
    resetFontResolverCaches();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  HWFontVariant variant({
    String family = 'Chewy',
    String? package,
    int weight = 400,
    bool italic = false,
  }) =>
      HWFontVariant(
        family: family,
        package: package,
        weight: weight,
        italic: italic,
      );

  group('PubspecFonts', () {
    test('reads every family with its declared weights and styles', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Chewy
      fonts:
        - asset: assets/fonts/Chewy-Regular.ttf
    - family: Roboto Mono
      fonts:
        - asset: assets/fonts/RobotoMono-Light.ttf
          weight: 300
        - asset: assets/fonts/RobotoMono-BoldItalic.ttf
          weight: 700
          style: italic
''',
      );

      final fonts = PubspecFonts.read(tempDir.path).families;

      expect(fonts.keys, containsAll(['Chewy', 'Roboto Mono']));
      expect(fonts['Chewy']!.single.weight, 400);
      expect(fonts['Chewy']!.single.italic, isFalse);
      final mono = fonts['Roboto Mono']!;
      expect(mono.map((f) => f.weight), [300, 700]);
      expect(mono.map((f) => f.italic), [false, true]);
    });

    test('a pubspec without a fonts section declares nothing', () {
      writeFontFixture(tempDir);
      expect(PubspecFonts.read(tempDir.path).families, isEmpty);
    });
  });

  group('FontResolver.resolveTextFont', () {
    test('resolves the app\'s own family to its asset key', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Chewy
      fonts:
        - asset: assets/fonts/Chewy-Regular.ttf
''',
      );

      expect(
        FontResolver(tempDir).resolveTextFont(variant()),
        'assets/fonts/Chewy-Regular.ttf',
      );
    });

    test('prefers the file declared at exactly the wanted weight and slant',
        () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-BoldItalic.ttf
          weight: 700
          style: italic
''',
      );
      final fonts = FontResolver(tempDir);

      expect(
        fonts.resolveTextFont(variant(family: 'Inter', weight: 700)),
        'assets/fonts/Inter-Bold.ttf',
      );
      expect(
        fonts.resolveTextFont(
          variant(family: 'Inter', weight: 700, italic: true),
        ),
        'assets/fonts/Inter-BoldItalic.ttf',
      );
    });

    test('a light target reaches down before it reaches up', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Thin.ttf
          weight: 100
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
''',
      );

      // 400 is closer to 700 in absolute distance, but CSS's rule looks lighter
      // first for anything at or below the regular weight.
      expect(
        FontResolver(tempDir).resolveTextFont(variant(family: 'Inter')),
        'assets/fonts/Inter-Thin.ttf',
      );
    });

    test('a heavy target reaches up before it reaches down', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Black.ttf
          weight: 900
''',
      );

      expect(
        FontResolver(tempDir)
            .resolveTextFont(variant(family: 'Inter', weight: 700)),
        'assets/fonts/Inter-Black.ttf',
      );
    });

    test('picks the closest weight on the side it looks at first', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Thin.ttf
          weight: 100
        - asset: assets/fonts/Inter-Light.ttf
          weight: 300
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
''',
      );

      expect(
        FontResolver(tempDir).resolveTextFont(variant(family: 'Inter')),
        'assets/fonts/Inter-Light.ttf',
      );
    });

    test('a file of the right slant wins however far its weight is off', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-ThinItalic.ttf
          weight: 100
          style: italic
''',
      );

      expect(
        FontResolver(tempDir).resolveTextFont(
          variant(family: 'Inter', weight: 700, italic: true),
        ),
        'assets/fonts/Inter-ThinItalic.ttf',
      );
    });

    test('falls back to the other slant when the family has only one', () {
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Chewy
      fonts:
        - asset: assets/fonts/Chewy-Regular.ttf
''',
      );

      expect(
        FontResolver(tempDir).resolveTextFont(variant(italic: true)),
        'assets/fonts/Chewy-Regular.ttf',
      );
    });

    test('namespaces a package family the way Flutter registers it', () {
      final package = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Brand
      fonts:
        - asset: fonts/Brand-Regular.ttf
''',
        assets: ['fonts/Brand-Regular.ttf'],
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'design_system', root: package.path),
        ],
      );

      expect(
        FontResolver(tempDir).resolveTextFont(
          variant(family: 'Brand', package: 'design_system'),
        ),
        'packages/design_system/fonts/Brand-Regular.ttf',
      );
    });

    test('a package file resolves relative to the package root', () {
      final package = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Brand
      fonts:
        - asset: assets/Brand-Regular.ttf
''',
        assets: ['assets/Brand-Regular.ttf'],
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'design_system', root: package.path),
        ],
      );

      final file = FontResolver(tempDir).resolveTextFontFile(
        variant(family: 'Brand', package: 'design_system'),
      );
      expect(file.existsSync(), isTrue);
      final expected = p.join(package.path, 'assets/Brand-Regular.ttf');
      expect(p.equals(file.path, expected), isTrue, reason: file.path);
    });

    test('a package declaring a lib/ path resolves inside lib/', () {
      final package = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Brand
      fonts:
        - asset: lib/fonts/Brand-Regular.ttf
''',
        assets: ['lib/fonts/Brand-Regular.ttf'],
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'design_system', root: package.path),
        ],
      );

      final file = FontResolver(tempDir).resolveTextFontFile(
        variant(family: 'Brand', package: 'design_system'),
      );
      expect(file.existsSync(), isTrue);
      final expected = p.join(package.path, 'lib/fonts/Brand-Regular.ttf');
      expect(p.equals(file.path, expected), isTrue, reason: file.path);
    });

    test('a namespaced declaration resolves under the package\'s lib/', () {
      final package = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Brand
      fonts:
        - asset: packages/design_system/fonts/Brand-Regular.ttf
''',
        assets: ['lib/fonts/Brand-Regular.ttf'],
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'design_system', root: package.path),
        ],
      );

      final file = FontResolver(tempDir).resolveTextFontFile(
        variant(family: 'Brand', package: 'design_system'),
      );
      expect(file.existsSync(), isTrue);
      final expected = p.join(package.path, 'lib/fonts/Brand-Regular.ttf');
      expect(p.equals(file.path, expected), isTrue, reason: file.path);
    });

    test('the app re-declaring a package family resolves in that package', () {
      final package = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Other
      fonts:
        - asset: lib/fonts/Other.ttf
''',
        assets: ['lib/fonts/Brand-Regular.ttf'],
      );
      writeFontFixture(
        tempDir,
        pubspecFonts: '''
    - family: Brand
      fonts:
        - asset: packages/design_system/fonts/Brand-Regular.ttf
''',
        packages: [
          FixturePackage(name: 'design_system', root: package.path),
        ],
      );

      final file =
          FontResolver(tempDir).resolveTextFontFile(variant(family: 'Brand'));
      expect(file.existsSync(), isTrue, reason: file.path);
      final expected = p.join(package.path, 'lib/fonts/Brand-Regular.ttf');
      expect(p.equals(file.path, expected), isTrue, reason: file.path);
    });

    test('a package naming another package\'s file resolves in that package',
        () {
      final designSystem = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Other
      fonts:
        - asset: lib/fonts/Other.ttf
''',
        assets: ['lib/fonts/Brand-Regular.ttf'],
      );
      final theme = writeFontPackage(
        tempDir,
        'app_theme',
        pubspecFonts: '''
    - family: Brand
      fonts:
        - asset: packages/design_system/fonts/Brand-Regular.ttf
''',
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'design_system', root: designSystem.path),
          FixturePackage(name: 'app_theme', root: theme.path),
        ],
      );

      final file = FontResolver(tempDir).resolveTextFontFile(
        variant(family: 'Brand', package: 'app_theme'),
      );
      expect(file.existsSync(), isTrue, reason: file.path);
      final expected = p.join(designSystem.path, 'lib/fonts/Brand-Regular.ttf');
      expect(p.equals(file.path, expected), isTrue, reason: file.path);
    });

    test('an undeclared family names the family and the pubspec section', () {
      writeFontFixture(tempDir);

      expect(
        () => FontResolver(tempDir).resolveTextFont(variant()),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Chewy'),
              contains('flutter: fonts:'),
              contains('pubspec.yaml'),
            ),
          ),
        ),
      );
    });

    test('a family missing from the named package says so', () {
      final package = writeFontPackage(
        tempDir,
        'design_system',
        pubspecFonts: '''
    - family: Other
      fonts:
        - asset: fonts/Other.ttf
''',
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'design_system', root: package.path),
        ],
      );

      final brand = variant(family: 'Brand', package: 'design_system');
      expect(
        () => FontResolver(tempDir).resolveTextFont(brand),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Brand'), contains('design_system')),
          ),
        ),
      );
    });

    test('an unresolvable package points at pub get', () {
      writeFontFixture(tempDir);

      expect(
        () => FontResolver(tempDir)
            .resolveTextFont(variant(family: 'Brand', package: 'not_a_dep')),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('not_a_dep'), contains('flutter pub get')),
          ),
        ),
      );
    });
  });

  group('FontResolver.resolveIconFont', () {
    final sdkRoot = flutterSdkRootForTests;

    test(
      'MaterialIcons comes out of the Flutter cache',
      () {
        writeFontFixture(tempDir, flutterSdkRoot: sdkRoot);

        final source = FontResolver(tempDir).resolveIconFont(
          const HWIconFont(family: 'MaterialIcons'),
        );

        expect(source.file.existsSync(), isTrue);
        expect(p.basename(source.file.path), 'MaterialIcons-Regular.otf');
        expect(source.extension, 'otf');
      },
      skip: materialIconsFont(sdkRoot) == null
          ? 'The Flutter SDK material fonts are not precached'
          : null,
    );

    test('MaterialIcons without a resolvable SDK points at pub get', () {
      writeFontFixture(tempDir);

      expect(
        () => FontResolver(tempDir)
            .resolveIconFont(const HWIconFont(family: 'MaterialIcons')),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('flutter pub get'),
          ),
        ),
      );
    });

    test('CupertinoIcons comes out of the cupertino_icons package', () {
      final package = writeFontPackage(
        tempDir,
        'cupertino_icons',
        pubspecFonts: '''
    - family: CupertinoIcons
      fonts:
        - asset: assets/CupertinoIcons.ttf
''',
        assets: ['assets/CupertinoIcons.ttf'],
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'cupertino_icons', root: package.path),
        ],
      );

      final source = FontResolver(tempDir).resolveIconFont(
        const HWIconFont(family: 'CupertinoIcons', package: 'cupertino_icons'),
      );

      expect(
        p.equals(
          source.file.path,
          p.join(package.path, 'assets', 'CupertinoIcons.ttf'),
        ),
        isTrue,
        reason: source.file.path,
      );
      expect(source.extension, 'ttf');
    });

    test('CupertinoIcons falls back to the layout the package always had', () {
      final package =
          Directory(p.join(tempDir.path, 'packages/cupertino_icons'))
            ..createSync(recursive: true);
      final font = File(p.join(package.path, 'assets', 'CupertinoIcons.ttf'));
      font.parent.createSync(recursive: true);
      font.writeAsBytesSync(const [0, 1]);
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'cupertino_icons', root: package.path),
        ],
      );

      final source = FontResolver(tempDir).resolveIconFont(
        const HWIconFont(family: 'CupertinoIcons', package: 'cupertino_icons'),
      );

      expect(p.equals(source.file.path, font.path), isTrue);
    });

    test('CupertinoIcons falls back when the family declares no file', () {
      final package = writeFontPackage(
        tempDir,
        'cupertino_icons',
        pubspecFonts: '''
    - family: CupertinoIcons
      fonts: []
''',
        assets: ['assets/CupertinoIcons.ttf'],
      );
      writeFontFixture(
        tempDir,
        packages: [
          FixturePackage(name: 'cupertino_icons', root: package.path),
        ],
      );

      final source = FontResolver(tempDir).resolveIconFont(
        const HWIconFont(family: 'CupertinoIcons', package: 'cupertino_icons'),
      );

      expect(
        p.equals(
          source.file.path,
          p.join(package.path, 'assets', 'CupertinoIcons.ttf'),
        ),
        isTrue,
        reason: source.file.path,
      );
    });

    test('any other icon font resolves through its own fonts declaration', () {
      final package = writeFontPackage(
        tempDir,
        'brand_icons',
        pubspecFonts: '''
    - family: BrandIcons
      fonts:
        - asset: fonts/BrandIcons.otf
''',
        assets: ['fonts/BrandIcons.otf'],
      );
      writeFontFixture(
        tempDir,
        packages: [FixturePackage(name: 'brand_icons', root: package.path)],
      );

      final source = FontResolver(tempDir).resolveIconFont(
        const HWIconFont(family: 'BrandIcons', package: 'brand_icons'),
      );

      expect(source.file.existsSync(), isTrue);
      expect(source.extension, 'otf');
    });

    test('an undeclared icon font is rejected', () {
      writeFontFixture(tempDir);

      expect(
        () => FontResolver(tempDir)
            .resolveIconFont(const HWIconFont(family: 'BrandIcons')),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('BrandIcons'),
          ),
        ),
      );
    });
  });

  group('FontResolver.subsetIconFont', () {
    final sdkRoot = flutterSdkRootForTests;
    final material = materialIconsFont(sdkRoot);

    test(
      'shrinks the icon font to the glyphs it was handed',
      () async {
        writeFontFixture(tempDir, flutterSdkRoot: sdkRoot);
        final fonts = FontResolver(tempDir);
        final source = fonts.resolveIconFont(
          const HWIconFont(family: 'MaterialIcons'),
        );

        final bytes = await fonts.subsetIconFont(source, {0xE88A, 0xE25B});

        expect(bytes, isNotEmpty);
        expect(
          bytes.length,
          lessThan(source.file.lengthSync()),
          reason: 'a subset of two glyphs must be smaller than the whole font',
        );
      },
      skip: material == null || !hasFontSubset(sdkRoot)
          ? 'The SDK font-subset binary is not precached'
          : null,
    );

    test(
      'the same glyphs of the same font are subset once per run',
      () async {
        writeFontFixture(tempDir, flutterSdkRoot: sdkRoot);
        final fonts = FontResolver(tempDir);
        final source = fonts.resolveIconFont(
          const HWIconFont(family: 'MaterialIcons'),
        );

        final first = await fonts.subsetIconFont(source, {0xE88A});
        final second =
            await FontResolver(tempDir).subsetIconFont(source, {0xE88A});

        expect(identical(first, second), isTrue);
      },
      skip: material == null || !hasFontSubset(sdkRoot)
          ? 'The SDK font-subset binary is not precached'
          : null,
    );

    test('copies the whole font and warns when the subsetter is missing',
        () async {
      final mockLogger = MockLogger();
      logger = mockLogger;
      addTearDown(() => logger = Logger());

      final package = writeFontPackage(
        tempDir,
        'brand_icons',
        pubspecFonts: '''
    - family: BrandIcons
      fonts:
        - asset: fonts/BrandIcons.otf
''',
        assets: ['fonts/BrandIcons.otf'],
      );
      writeFontFixture(
        tempDir,
        packages: [FixturePackage(name: 'brand_icons', root: package.path)],
      );

      final fonts = FontResolver(tempDir);
      final source = fonts.resolveIconFont(
        const HWIconFont(family: 'BrandIcons', package: 'brand_icons'),
      );
      final bytes = await fonts.subsetIconFont(source, {0xE88A});

      expect(bytes, source.file.readAsBytesSync());
      verify(
        () => mockLogger.warn(any(that: contains('font-subset'))),
      ).called(1);
    });
  });
}
