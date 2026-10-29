import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/font_resolver.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';
import '../helpers/mock_logger.dart';
import '../helpers/xcode_project.dart';

/// The icon font the fixture ships, declared the way an icon package declares
/// one so the tests never reach outside the temp project.
const _brandIcons = HWIconFont(family: 'BrandIcons', package: 'brand_icons');

const _moodIcons = HWIconData.resolved(
  'mood',
  entries: [
    HWIconEntry('happy', 0xE88A),
    HWIconEntry('sad', 0xE25B),
  ],
  iconFont: _brandIcons,
  defaultValue: 0xE88A,
  previewValue: 0xE25B,
);

WidgetSpec _spec({
  required HWWidget widget,
  List<HWDataType<dynamic>> dataFields = const [],
  String className = 'Mood',
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: className,
        android: const HomeWidgetAndroidConfiguration(
          packageName: 'com.example',
        ),
        iOS: const HomeWidgetIOSConfiguration(groupId: 'group.example'),
        widget: widget,
      ),
      className: className,
      dataFields: dataFields,
      widgetTree: widget,
    );

void main() {
  late Directory tempDir;
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.success(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);

    tempDir = Directory.systemTemp.createTempSync('hw_font_generation');
    resetFontResolverCaches();
    Directory(p.join(tempDir.path, 'android', 'app'))
        .createSync(recursive: true);
    writeRunnerXcodeProject(tempDir);

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
      pubspecFonts: '''
    - family: Chewy
      fonts:
        - asset: assets/fonts/Chewy-Regular.ttf
        - asset: assets/fonts/Chewy-BoldItalic.ttf
          weight: 700
          style: italic
''',
      packages: [FixturePackage(name: 'brand_icons', root: package.path)],
    );
  });

  tearDown(() {
    logger = Logger();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<String> generateSwift(WidgetSpec spec) async {
    await IosGenerator(spec: spec, projectRoot: tempDir).generate();
    return File(
      p.join(
        tempDir.path,
        'ios',
        '${spec.className}HomeWidget',
        'Widget.swift',
      ),
    ).readAsStringSync();
  }

  Future<String> generateKotlin(WidgetSpec spec) async {
    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();
    return File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/example',
        '${spec.className}HomeWidget.kt',
      ),
    ).readAsStringSync();
  }

  group('Swift hwFont', () {
    test('the text calls the constant helper, which is in the file', () async {
      final swift = await generateSwift(
        _spec(
          widget: const HWText.fixed(
            'plain',
            style: HWTextStyle(fontFamily: 'Chewy', fontSize: 20),
          ),
        ),
      );

      expect(swift, contains('.font(hwFont("Chewy", 400, false, 20))'));
      // Which file that is, is read from the manifest on the device rather
      // than written into the extension here.
      expect(swift, contains('appendingPathComponent("FontManifest.json")'));
      expect(swift, isNot(contains('assets/fonts/Chewy-Regular.ttf')));
      // The loaders it calls have to be in the file too.
      expect(swift, contains('func hwAssetFont(_ asset: String'));
      expect(swift, contains('import CoreText'));
    });

    test('is left out of a widget that renders in the system font', () async {
      final swift = await generateSwift(
        _spec(widget: const HWText.fixed('plain')),
      );

      expect(swift, isNot(contains('func hwFont(')));
    });

    test('the helpers iOS has no body for leave no empty bodies behind',
        () async {
      final swift = await generateSwift(
        _spec(
          widget: const HWText.fixed(
            'plain',
            style: HWTextStyle(fontFamily: 'Chewy'),
          ),
        ),
      );

      for (final helper in HWNativeHelper.values) {
        if (helper.swift != null) continue;
        expect(swift, isNot(contains(helper.name)), reason: helper.name);
      }
      expect(swift, contains('func hwFont('));
      // Three blank lines in a row is what a helper with an empty body leaves.
      expect(swift, isNot(contains('\n\n\n\n')));
    });
  });

  group('Kotlin typeface lookup', () {
    test('the text asks the core plugin for the family', () async {
      final kotlin = await generateKotlin(
        _spec(
          widget: const HWText.fixed(
            'plain',
            style: HWTextStyle(fontFamily: 'Chewy'),
          ),
        ),
      );

      expect(
        kotlin,
        contains('HomeWidgetFonts.typeface(context, "Chewy", 400, false)'),
      );
      // Which file that is, the plugin reads off the device.
      expect(kotlin, isNot(contains('assets/fonts/Chewy-Regular.ttf')));
    });

    test('the Swift-only font helpers leave no empty bodies behind', () async {
      final kotlin = await generateKotlin(
        _spec(
          widget: const HWText.fixed(
            'plain',
            style: HWTextStyle(fontFamily: 'Chewy'),
          ),
        ),
      );

      for (final helper in HWNativeHelper.values) {
        if (helper.kotlin != null) continue;
        expect(kotlin, isNot(contains(helper.name)), reason: helper.name);
      }
      expect(kotlin, isNot(contains('hwAssetFont')));
      expect(kotlin, isNot(contains('hwBundledFont')));
      expect(kotlin, isNot(contains('hwFont')));
      // Three blank lines in a row is what a helper with an empty body leaves.
      expect(kotlin, isNot(contains('\n\n\n\n')));
    });
  });

  group('icon fields', () {
    // 0xE88A and 0xE25B, the codepoints the generated code stores.
    const happy = 59530;
    const sad = 57947;

    // What the parser stamps onto an icon of the widget class `Mood`; a
    // hand-built tree has to spell it out to name the same resource the CLI
    // copies the font to.
    const icon =
        HWIcon.resolved(_moodIcons, fontResourcePrefix: 'hw_font_mood');

    test('travel through the Swift data struct as a codepoint', () async {
      final swift = await generateSwift(
        _spec(widget: icon, dataFields: const [_moodIcons]),
      );

      expect(swift, contains('let mood: Int?'));
      expect(
        swift,
        contains(
          'mood: (defaults?.object(forKey: "\\(paramPrefix).mood") as? Int '
          '?? $happy),',
        ),
      );
      // The gallery shows the preview icon before the app has saved one.
      expect(
        swift,
        contains(
          'mood: (defaults?.object(forKey: "\\(paramPrefix).mood") as? Int '
          '?? $sad),',
        ),
      );
      expect(
        swift,
        contains(
          '.font(hwBundledFont("hw_font_icons_brandicons__brand_icons", '
          'size: 24))',
        ),
      );
    });

    test('travel through the Kotlin data class as a codepoint', () async {
      final kotlin = await generateKotlin(
        _spec(widget: icon, dataFields: const [_moodIcons]),
      );

      expect(kotlin, contains('val mood: Int? = null,'));
      expect(
        kotlin,
        contains(
          'mood = if (prefs.contains("\${PREFERENCES_PREFIX}.mood")) '
          'prefs.getInt("\${PREFERENCES_PREFIX}.mood", 0) else $happy,',
        ),
      );
      expect(
        kotlin,
        contains('R.font.hw_font_mood__icons_brandicons__brand_icons'),
      );
    });

    test('a JSON icon leaf reads its codepoint out of the group', () async {
      const field = HWJson('profile', _moodIcons);
      const jsonIcon =
          HWIcon.resolved(field, fontResourcePrefix: 'hw_font_mood');
      final swift = await generateSwift(
        _spec(widget: jsonIcon, dataFields: const [field]),
      );
      final kotlin = await generateKotlin(
        _spec(widget: jsonIcon, dataFields: const [field]),
      );

      expect(swift, contains('let mood: Int'));
      expect(swift, contains('(values["mood"] as? Int) ?? $happy'));
      expect(kotlin, contains('val mood: Int = $happy,'));
      expect(kotlin, contains('json.optInt("mood") else $happy,'));
    });

    test('a time-based icon reads out of the active entry', () async {
      const field = HWTimedData(_moodIcons);
      const timedIcon =
          HWIcon.resolved(field, fontResourcePrefix: 'hw_font_mood');
      final swift = await generateSwift(
        _spec(widget: timedIcon, dataFields: const [field]),
      );
      final kotlin = await generateKotlin(
        _spec(widget: timedIcon, dataFields: const [field]),
      );

      expect(swift, contains('(timedValues["mood"] as? Int) ?? $happy'));
      expect(kotlin, contains('timedValues.optInt("mood") else $happy,'));
    });

    test('the font is copied into both native projects', () async {
      final spec = _spec(widget: icon, dataFields: const [_moodIcons]);
      await generateSwift(spec);
      await generateKotlin(spec);

      expect(
        File(
          p.join(
            tempDir.path,
            'ios/MoodHomeWidget/hw_font_icons_brandicons__brand_icons.otf',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            tempDir.path,
            'android/app/src/main/res/font/'
            'hw_font_mood__icons_brandicons__brand_icons.otf',
          ),
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('hwMirroredIcons', () {
    const directional = HWIconData.resolved(
      'mood',
      entries: [
        HWIconEntry('happy', 0xE88A),
        HWIconEntry('back', 0xE5C4, matchTextDirection: true),
        HWIconEntry('forward', 0xE5C8, matchTextDirection: true),
      ],
      iconFont: _brandIcons,
    );
    const icon =
        HWIcon.resolved(directional, fontResourcePrefix: 'hw_font_mood');

    test('holds every directional glyph the widget can draw', () async {
      final spec = _spec(widget: icon, dataFields: const [directional]);

      expect(
        await generateKotlin(spec),
        contains(
          'private val hwMirroredIcons: Set<Int> = setOf(0xE5C4, 0xE5C8)',
        ),
      );
      expect(
        await generateSwift(spec),
        contains('private let hwMirroredIcons: Set<Int> = [0xE5C4, 0xE5C8]'),
      );
    });

    test('is empty where no glyph is directional', () async {
      final spec = _spec(
        widget: const HWIcon.resolved(
          _moodIcons,
          fontResourcePrefix: 'hw_font_mood',
        ),
        dataFields: const [_moodIcons],
      );

      expect(
        await generateKotlin(spec),
        contains('private val hwMirroredIcons: Set<Int> = setOf()'),
      );
      expect(
        await generateSwift(spec),
        contains('private let hwMirroredIcons: Set<Int> = []'),
      );
    });

    test('is left out of a widget with no icon field', () async {
      final spec = _spec(widget: const HWText.fixed('plain'));

      expect(await generateKotlin(spec), isNot(contains('hwMirroredIcons')));
      expect(await generateSwift(spec), isNot(contains('hwMirroredIcons')));
    });
  });
}
