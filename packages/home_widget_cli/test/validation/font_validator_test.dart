import 'dart:io';

import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/font_resolver.dart';
import 'package:home_widget_cli/src/validation/font_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';

const _brandIcons = HWIconFont(family: 'BrandIcons', package: 'brand_icons');

const _brandIconsDeclaration = '''
    - family: BrandIcons
      fonts:
        - asset: fonts/BrandIcons.otf
''';

WidgetSpec _spec({
  required HWWidget widget,
  List<HWDataType<dynamic>> dataFields = const [],
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Mood',
        android: const HomeWidgetAndroidConfiguration(),
        widget: widget,
      ),
      className: 'Mood',
      dataFields: dataFields,
      widgetTree: widget,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hw_font_validator');
    resetFontResolverCaches();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A project declaring the Chewy family and shipping the BrandIcons package.
  void writeCompleteProject({
    String? lockedHomeWidgetVersion,
    String homeWidgetSource = 'hosted',
  }) {
    final package = writeFontPackage(
      tempDir,
      'brand_icons',
      pubspecFonts: _brandIconsDeclaration,
      assets: ['fonts/BrandIcons.otf'],
    );
    writeFontFixture(
      tempDir,
      pubspecFonts: '''
    - family: Chewy
      fonts:
        - asset: assets/fonts/Chewy-Regular.ttf
''',
      packages: [FixturePackage(name: 'brand_icons', root: package.path)],
      lockedHomeWidgetVersion: lockedHomeWidgetVersion,
      homeWidgetSource: homeWidgetSource,
    );
  }

  test('a widget using no font or icon is never looked at', () {
    // No pubspec at all: a spec that names no font must not care.
    expect(
      () => validateFonts(
        _spec(widget: const HWText.fixed('plain')),
        tempDir,
      ),
      returnsNormally,
    );
  });

  test('accepts a widget whose fonts and icons all resolve', () {
    writeCompleteProject();

    expect(
      () => validateFonts(
        _spec(
          widget: const HWColumn(
            children: [
              HWText.fixed('plain', style: HWTextStyle(fontFamily: 'Chewy')),
              HWIcon.glyph(0xE88A, font: _brandIcons),
            ],
          ),
        ),
        tempDir,
      ),
      returnsNormally,
    );
  });

  test('rejects a text font family nothing declares', () {
    writeCompleteProject();

    expect(
      () => validateFonts(
        _spec(
          widget: const HWText.fixed(
            'plain',
            style: HWTextStyle(fontFamily: 'Missing'),
          ),
        ),
        tempDir,
      ),
      throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          contains('Missing'),
        ),
      ),
    );
  });

  test('rejects an icon font that is not on disk', () {
    writeFontFixture(tempDir);

    expect(
      () => validateFonts(
        _spec(widget: const HWIcon.glyph(0xE88A, font: _brandIcons)),
        tempDir,
      ),
      throwsA(isA<GeneratorError>()),
    );
  });

  test('rejects an icon field whose default is not one of its icons', () {
    writeCompleteProject();
    const field = HWIconData.resolved(
      'mood',
      entries: [HWIconEntry('happy', 0xE88A)],
      iconFont: _brandIcons,
      defaultValue: 0xE25B,
    );

    expect(
      () => validateFonts(
        _spec(widget: const HWIcon(field), dataFields: const [field]),
        tempDir,
      ),
      throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          contains('defaultValue'),
        ),
      ),
    );
  });

  test('rejects an icon field naming the same icon twice', () {
    writeCompleteProject();
    const field = HWIconData.resolved(
      'mood',
      entries: [
        HWIconEntry('happy', 0xE88A),
        HWIconEntry('happy', 0xE25B),
      ],
      iconFont: _brandIcons,
    );

    expect(
      () => validateFonts(
        _spec(widget: const HWIcon(field), dataFields: const [field]),
        tempDir,
      ),
      throwsA(
        isA<GeneratorError>().having(
          (e) => e.message,
          'message',
          contains('twice'),
        ),
      ),
    );
  });

  group('the home_widget version gate', () {
    HWWidget fontWidget() => const HWText.fixed(
          'plain',
          style: HWTextStyle(fontFamily: 'Chewy'),
        );

    test('rejects a hosted home_widget older than the font release', () {
      writeCompleteProject(lockedHomeWidgetVersion: '0.9.2');

      expect(
        () => validateFonts(_spec(widget: fontWidget()), tempDir),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('0.9.2'),
              contains(minimumFontHomeWidgetVersion),
              contains('flutter pub get'),
            ),
          ),
        ),
      );
    });

    test('accepts the font release itself and anything newer', () {
      for (final version in const ['0.10.0', '0.10.1', '1.0.0']) {
        writeCompleteProject(lockedHomeWidgetVersion: version);
        expect(
          () => validateFonts(_spec(widget: fontWidget()), tempDir),
          returnsNormally,
          reason: version,
        );
      }
    });

    test('accepts a pre-release of the font release', () {
      writeCompleteProject(lockedHomeWidgetVersion: '0.10.0-dev.1');

      expect(
        () => validateFonts(_spec(widget: fontWidget()), tempDir),
        returnsNormally,
      );
    });

    test('skips a path, git or workspace dependency', () {
      for (final source in const ['path', 'git', 'sdk']) {
        writeCompleteProject(
          lockedHomeWidgetVersion: '0.9.2',
          homeWidgetSource: source,
        );
        expect(
          () => validateFonts(_spec(widget: fontWidget()), tempDir),
          returnsNormally,
          reason: source,
        );
      }
    });

    test('is silent without a lockfile', () {
      writeCompleteProject();

      expect(
        () => validateFonts(_spec(widget: fontWidget()), tempDir),
        returnsNormally,
      );
    });

    test('does not apply to a widget using neither fonts nor icons', () {
      writeCompleteProject(lockedHomeWidgetVersion: '0.9.2');

      expect(
        () =>
            validateFonts(_spec(widget: const HWText.fixed('plain')), tempDir),
        returnsNormally,
      );
    });
  });
}
