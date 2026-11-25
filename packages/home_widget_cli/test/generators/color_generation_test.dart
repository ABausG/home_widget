import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/xcode_project.dart';

const _tree = HWColumn(
  children: [
    HWText(
      HWString.fixed('a'),
      style: HWTextStyle(color: HWColor('accent', defaultValue: 0xFF6750A4)),
    ),
    HWColoredBox(
      color: HWJson<int>('brand', HWColor('fill', defaultValue: 0xFF112233)),
      child: HWText(HWString.fixed('b')),
    ),
    HWColoredBox(
      color: HWTimedData<int>(HWColor('phase')),
      child: HWText(HWString.fixed('c')),
    ),
    HWRow.builder(
      'chips',
      item: HWColoredBox(
        color: HWItemData<int>(
          HWColor('tint'),
          previewValues: [0xFF000000, 0xFFFFFFFF],
        ),
        child: HWText(HWString.fixed('d')),
      ),
    ),
  ],
);

WidgetSpec _spec({
  HWWidget tree = _tree,
  HWDataType<int>? androidBackground,
  HWDataType<int>? iosBackground,
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Brand',
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.brand',
          backgroundColor: androidBackground ??
              const HWDefaultColor(HWColorRole.defaultBackground),
        ),
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.brand',
          backgroundColor: iosBackground,
        ),
      ),
      className: 'Brand',
      dataFields: [
        ...tree.dataDependencies,
        for (final color in [androidBackground, iosBackground])
          ...?color?.readValues.where((value) => value.isDataDependency),
      ],
      widgetTree: tree,
    );

void main() {
  group('the Dart helper', () {
    test('hands every stored color over and back as a Flutter Color', () {
      final output = DartHelperGenerator(_spec()).generate();
      expect(output, contains("import 'dart:ui' show Color, ColorSpace;"));
      expect(output, contains('Color? accent,'));
      expect(
        output,
        contains(
          'accent.withValues(colorSpace: ColorSpace.sRGB).toARGB32()',
        ),
      );
      expect(
        output,
        contains(
          r"accent: _$color(await HomeWidget.getWidgetData<int>("
          r"'${_$paramPrefix}.accent', defaultValue: 0xFF6750A4, ",
        ),
      );
      expect(output, contains('final Color? fill;'));
      expect(
        output,
        contains(r"fill: _$color(_readInt(json['fill']) ?? 0xFF112233),"),
      );
      expect(output, contains('final Color? tint;'));
      expect(output, contains('final Color? phase;'));
      expect(
        output,
        contains(
          r'Color? _$color(int? argb) => argb == null ? null : Color(argb);',
        ),
      );
      expect(output, contains('int? _readInt(Object? value)'));
    });

    test('names no Color for a widget storing none', () {
      final output = DartHelperGenerator(
        WidgetSpec(
          data: HomeWidget(name: 'Plain'),
          className: 'Plain',
          dataFields: const [HWString('label')],
        ),
      ).generate();
      expect(output, isNot(contains('dart:ui')));
      expect(output, isNot(contains(r'_$color')));
    });
  });

  group('the native widgets', () {
    late Directory tempDir;
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
      logger = mockLogger;
      when(() => mockLogger.success(any())).thenReturn(null);
      when(() => mockLogger.info(any())).thenReturn(null);
      when(() => mockLogger.detail(any())).thenReturn(null);
      when(() => mockLogger.warn(any())).thenReturn(null);
      tempDir = Directory.systemTemp.createTempSync('color_gen_test');
      Directory(p.join(tempDir.path, 'android', 'app'))
          .createSync(recursive: true);
      writeRunnerXcodeProject(tempDir);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    Future<String> kotlin(WidgetSpec spec) async {
      await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();
      return File(
        p.join(
          tempDir.path,
          'android/app/src/main/kotlin/com/brand/BrandHomeWidget.kt',
        ),
      ).readAsStringSync();
    }

    Future<String> swift(WidgetSpec spec) async {
      await IosGenerator(spec: spec, projectRoot: tempDir).generate();
      return File(
        p.join(tempDir.path, 'ios/BrandHomeWidget/Widget.swift'),
      ).readAsStringSync();
    }

    test('Android reads every stored color as a Long', () async {
      final content = await kotlin(_spec());
      expect(content, contains('val accent: Long? = null,'));
      expect(content, contains('optLong("fill")'));
      expect(content, contains('optLong("phase")'));
      expect(content, contains('optLong("tint")'));
      expect(content, contains('private fun hwColor(argb: Long?) ='));
      expect(content, contains('4278190080L'));
      expect(
        content,
        contains('background(GlanceTheme.colors.widgetBackground)'),
      );
      expect(content, isNot(contains('hwDayNight')));
    });

    test('Android paints a stored background, or the default one', () async {
      final content = await kotlin(
        _spec(
          androidBackground: const HWAppearanceData<int>(
            light: HWColor('bgLight'),
            dark: HWDefaultColor(HWColorRole.defaultBackground),
          ),
        ),
      );
      expect(
        content,
        contains(
          'background((hwAppearanceColor(context, hwColor(widgetData.bgLight), '
          'GlanceTheme.colors.widgetBackground) ?: '
          'GlanceTheme.colors.widgetBackground))',
        ),
      );
      expect(content, contains('private fun hwAppearanceColor('));
      expect(
        content,
        contains('import es.antonborri.home_widget.HomeWidgetAppearance'),
      );
      expect(content, isNot(contains('hwDayNight')));
      expect(content, contains('val bgLight: Long? = null,'));
    });

    test('iOS reads every stored color as an Int', () async {
      final content = await swift(_spec());
      expect(content, contains('let accent: Int?'));
      expect(content, contains('func hwColor(_ argb: Int?) -> Color?'));
      expect(content, contains('.foregroundColor(hwColor(entry.data.accent))'));
      expect(content, contains('.applyContainerBackground()'));
    });

    test('iOS keeps the container background while a color has no value',
        () async {
      final content = await swift(
        _spec(
          iosBackground: const HWAppearanceData<int>(
            light: HWColor('bgLight'),
            dark: HWColor.fixed(0xFF000000),
          ),
        ),
      );
      expect(
        content,
        contains(
          '.applyContainerBackground(optional: hwAppearance(hwEnvironment, '
          'light: hwColor(entry.data.bgLight), ',
        ),
      );
      expect(
        content,
        contains(
          'func applyContainerBackground(optional backgroundColor: Color?) '
          '-> some View {',
        ),
      );
      expect(content, contains('func applyContainerBackground() -> some View'));
      expect(
        content,
        contains(
          'func applyContainerBackground<T: View>(_ backgroundView: T) '
          '-> some View',
        ),
      );
      expect(content, contains('@Environment(\\.self) var hwEnvironment'));
      expect(content, contains('func hwIsAccented('));
    });

    test('iOS paints a constant background as it is', () async {
      final content = await swift(
        _spec(iosBackground: const HWColor.fixed(0xFF000000)),
      );
      expect(
        content,
        contains(
          '.applyContainerBackground(Color(red: 0.0, green: 0.0, blue: 0.0, '
          'opacity: 1.0))',
        ),
      );
      expect(content, isNot(contains('optional backgroundColor')));
      expect(content, isNot(contains('func applyContainerBackground() ->')));
    });

    test('iOS paints a pick between constant colors as a constant', () async {
      final content = await swift(
        _spec(
          iosBackground: const HWAppearanceData<int>(
            light: HWColor.fixed(0xFFFFFFFF),
            dark: HWDefaultColor(HWColorRole.contentPrimary),
          ),
        ),
      );
      expect(
        content,
        contains(
          '.applyContainerBackground((hwAppearance(hwEnvironment, '
          'light: Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0), '
          'dark: Color.primary) ?? '
          'Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)))',
        ),
      );
      expect(content, isNot(contains('optional backgroundColor')));
      expect(content, isNot(contains('func applyContainerBackground() ->')));
    });

    test('each platform declares the helpers of its own background only',
        () async {
      final androidOnly = _spec(
        tree: const HWText(HWString.fixed('a')),
        androidBackground: const HWAppearanceData<int>(
          light: HWColor('androidLight'),
          dark: HWColor('androidDark'),
        ),
      );
      expect(
        androidOnly.androidNativeHelpers,
        containsAll([
          HWNativeHelper.hwAppearanceColor,
          HWNativeHelper.hwColor,
        ]),
      );
      expect(androidOnly.iosNativeHelpers, isEmpty);
      expect(androidOnly.androidUsesPluginAppearance, isTrue);

      final iosOnly = _spec(
        tree: const HWText(HWString.fixed('a')),
        androidBackground: const HWColor.fixed(0xFF000000),
        iosBackground: const HWAppearanceData<int>(
          light: HWColor('iosLight'),
          dark: HWDefaultColor(HWColorRole.contentPrimary),
        ),
      );
      expect(iosOnly.androidNativeHelpers, isEmpty);
      expect(iosOnly.androidUsesPluginAppearance, isFalse);
    });
  });
}
