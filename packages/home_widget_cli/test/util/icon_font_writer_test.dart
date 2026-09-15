import 'dart:io';

import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/font_resolver.dart';
import 'package:home_widget_cli/src/util/icon_font_writer.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';

class MockLogger extends Mock implements Logger {}

/// The icon font the fixture ships, declared the way an icon package declares
/// one so nothing outside the temp project has to exist.
const _brandIcons = HWIconFont(family: 'BrandIcons', package: 'brand_icons');

WidgetSpec _spec({
  String className = 'Mood',
  required HWWidget widget,
  List<HWDataType<dynamic>> dataFields = const [],
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: className,
        android: const HomeWidgetAndroidConfiguration(),
        iOS: const HomeWidgetIOSConfiguration(groupId: 'group.example'),
        widget: widget,
      ),
      className: className,
      dataFields: dataFields,
      widgetTree: widget,
    );

void main() {
  late Directory tempDir;
  late FontResolver fonts;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hw_icon_fonts');
    resetFontResolverCaches();

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
    fonts = FontResolver(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Directory androidFontDir() => Directory(
        p.join(tempDir.path, 'android/app/src/main/res/font'),
      );

  group('writeAndroidIconFonts', () {
    test('writes one resource per icon font, named after the widget', () async {
      final spec = _spec(
        widget: const HWIcon.glyph(0xE88A, font: _brandIcons),
      );

      final result = await writeAndroidIconFonts(
        spec: spec,
        projectRoot: tempDir,
        fonts: fonts,
      );

      expect(
        result.written,
        ['hw_font_mood__icons_brandicons__brand_icons.otf'],
      );
      expect(
        File(p.join(androidFontDir().path, result.written.single)).existsSync(),
        isTrue,
      );
    });

    test('leaves an unchanged font untouched', () async {
      final spec = _spec(
        widget: const HWIcon.glyph(0xE88A, font: _brandIcons),
      );

      await writeAndroidIconFonts(
        spec: spec,
        projectRoot: tempDir,
        fonts: fonts,
      );
      final file = File(
        p.join(
          androidFontDir().path,
          'hw_font_mood__icons_brandicons__brand_icons.otf',
        ),
      );
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final before = file.statSync().modified;

      await writeAndroidIconFonts(
        spec: spec,
        projectRoot: tempDir,
        fonts: fonts,
      );

      expect(file.statSync().modified, before);
    });

    test('prunes this widget\'s leftovers and nothing else', () async {
      final fontDir = androidFontDir()..createSync(recursive: true);
      final stale = File(
        p.join(fontDir.path, 'hw_font_mood__icons_materialicons.otf'),
      )..writeAsBytesSync(const [9]);
      final otherWidget = File(
        p.join(fontDir.path, 'hw_font_weather__icons_brandicons.otf'),
      )..writeAsBytesSync(const [9]);
      // A widget whose snake name starts with this one's is a different widget.
      final longerName = File(
        p.join(fontDir.path, 'hw_font_mood_board__icons_brandicons.otf'),
      )..writeAsBytesSync(const [9]);
      final appOwned = File(p.join(fontDir.path, 'my_brand.ttf'))
        ..writeAsBytesSync(const [9]);

      final result = await writeAndroidIconFonts(
        spec: _spec(widget: const HWIcon.glyph(0xE88A, font: _brandIcons)),
        projectRoot: tempDir,
        fonts: fonts,
      );

      expect(result.removed, ['hw_font_mood__icons_materialicons.otf']);
      expect(stale.existsSync(), isFalse);
      expect(otherWidget.existsSync(), isTrue);
      expect(longerName.existsSync(), isTrue);
      expect(appOwned.existsSync(), isTrue);
    });

    test(
        'a widget whose snake name is this widget\'s plus "_icons" never '
        'prunes this widget\'s font, and vice versa', () async {
      final fontDir = androidFontDir()..createSync(recursive: true);

      final weatherFont = File(
        p.join(fontDir.path, 'hw_font_weather__icons_materialicons.otf'),
      )..writeAsBytesSync(const [9]);
      final weatherIconsFont = File(
        p.join(
          fontDir.path,
          'hw_font_weather_icons__icons_materialicons.otf',
        ),
      )..writeAsBytesSync(const [9]);

      await writeAndroidIconFonts(
        spec: _spec(
          className: 'Weather',
          widget: const HWText.fixed('no icons'),
        ),
        projectRoot: tempDir,
        fonts: fonts,
      );
      expect(weatherFont.existsSync(), isFalse);
      expect(weatherIconsFont.existsSync(), isTrue);

      weatherFont.writeAsBytesSync(const [9]);
      await writeAndroidIconFonts(
        spec: _spec(
          className: 'WeatherIcons',
          widget: const HWText.fixed('no icons'),
        ),
        projectRoot: tempDir,
        fonts: fonts,
      );
      expect(weatherFont.existsSync(), isTrue);
      expect(weatherIconsFont.existsSync(), isFalse);
    });

    test('a widget that stopped drawing icons loses its fonts', () async {
      await writeAndroidIconFonts(
        spec: _spec(widget: const HWIcon.glyph(0xE88A, font: _brandIcons)),
        projectRoot: tempDir,
        fonts: fonts,
      );

      final result = await writeAndroidIconFonts(
        spec: _spec(widget: const HWText.fixed('no icons')),
        projectRoot: tempDir,
        fonts: fonts,
      );

      expect(result.written, isEmpty);
      expect(
        result.removed,
        ['hw_font_mood__icons_brandicons__brand_icons.otf'],
      );
      expect(androidFontDir().listSync(), isEmpty);
    });

    test('logs what it generated and what it removed', () async {
      final mockLogger = MockLogger();
      logger = mockLogger;
      addTearDown(() => logger = Logger());

      await writeAndroidIconFonts(
        spec: _spec(widget: const HWIcon.glyph(0xE88A, font: _brandIcons)),
        projectRoot: tempDir,
        fonts: fonts,
      );
      await writeAndroidIconFonts(
        spec: _spec(widget: const HWText.fixed('no icons')),
        projectRoot: tempDir,
        fonts: fonts,
      );

      verify(
        () => mockLogger.detail(any(that: startsWith('Generated: '))),
      ).called(1);
      verify(
        () => mockLogger.detail(any(that: startsWith('Removed stale: '))),
      ).called(1);
    });
  });

  group('writeIosIconFonts', () {
    late Directory extensionDir;

    setUp(() {
      extensionDir = Directory(p.join(tempDir.path, 'ios', 'MoodHomeWidget'))
        ..createSync(recursive: true);
    });

    test('writes the font next to the generated widget, un-namespaced',
        () async {
      final result = await writeIosIconFonts(
        spec: _spec(widget: const HWIcon.glyph(0xE88A, font: _brandIcons)),
        extensionDir: extensionDir,
        fonts: fonts,
      );

      expect(result.written, ['hw_font_icons_brandicons__brand_icons.otf']);
      expect(
        File(p.join(extensionDir.path, result.written.single)).existsSync(),
        isTrue,
      );
    });

    test('prunes only the font files it owns', () async {
      final stale = File(
        p.join(extensionDir.path, 'hw_font_icons_materialicons.otf'),
      )..writeAsBytesSync(const [9]);
      final generated = File(p.join(extensionDir.path, 'Widget.swift'))
        ..writeAsStringSync('// widget');

      final result = await writeIosIconFonts(
        spec: _spec(widget: const HWIcon.glyph(0xE88A, font: _brandIcons)),
        extensionDir: extensionDir,
        fonts: fonts,
      );

      expect(result.removed, ['hw_font_icons_materialicons.otf']);
      expect(stale.existsSync(), isFalse);
      expect(generated.existsSync(), isTrue);
    });
  });

  test('two icon fonts writing the same file name are rejected', () async {
    // Two families of one package whose resource names snake down to the same
    // string: one file cannot carry the glyphs of both.
    final package = writeFontPackage(
      tempDir,
      'brand_icons',
      pubspecFonts: '''
    - family: Brand Icons
      fonts:
        - asset: fonts/BrandIcons.otf
    - family: Brand-Icons
      fonts:
        - asset: fonts/BrandIcons.otf
''',
      assets: ['fonts/BrandIcons.otf'],
    );
    writeFontFixture(
      tempDir,
      packages: [FixturePackage(name: 'brand_icons', root: package.path)],
    );

    await expectLater(
      writeAndroidIconFonts(
        spec: _spec(
          widget: const HWColumn(
            children: [
              HWIcon.glyph(
                0xE88A,
                font: HWIconFont(family: 'Brand Icons', package: 'brand_icons'),
              ),
              HWIcon.glyph(
                0xE25B,
                font: HWIconFont(family: 'Brand-Icons', package: 'brand_icons'),
              ),
            ],
          ),
        ),
        projectRoot: tempDir,
        fonts: FontResolver(tempDir),
      ),
      throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          allOf(contains('Brand Icons'), contains('Brand-Icons')),
        ),
      ),
    );
  });

  test('two app-declared icon fonts writing the same file name are rejected',
      () async {
    writeFontFixture(
      tempDir,
      pubspecFonts: '''
    - family: App Icons
      fonts:
        - asset: fonts/AppIcons.otf
    - family: App-Icons
      fonts:
        - asset: fonts/AppIcons.otf
''',
    );
    File(p.join(tempDir.path, 'fonts', 'AppIcons.otf'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(const [0, 1, 2, 3]);

    await expectLater(
      writeAndroidIconFonts(
        spec: _spec(
          widget: const HWColumn(
            children: [
              HWIcon.glyph(0xE88A, font: HWIconFont(family: 'App Icons')),
              HWIcon.glyph(0xE25B, font: HWIconFont(family: 'App-Icons')),
            ],
          ),
        ),
        projectRoot: tempDir,
        fonts: FontResolver(tempDir),
      ),
      throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('"App Icons"'),
            contains('"App-Icons"'),
            isNot(contains('of package')),
          ),
        ),
      ),
    );
  });
}
