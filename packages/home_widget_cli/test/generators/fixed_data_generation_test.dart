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

const _percent = HWNumberFormat.percent();

const _constantLocalized =
    HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'});

/// Fixed values next to one stored field.
const _dataForms = HWColumn(
  children: [
    HWText(HWString.fixed('Hi')),
    HWText.number(HWInt.fixed(3), format: _percent),
    HWText.number(HWDouble.fixed(2.5)),
    HWText(HWString('label')),
  ],
);

/// One fixed value of every type a text renders, and nothing stored.
const _onlyFixed = HWColumn(
  children: [
    HWText(HWString.fixed('Hi')),
    HWText.number(HWInt.fixed(3)),
    HWText.number(HWDouble.fixed(2.5)),
    HWText(HWBool.fixed(true)),
    HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00Z')),
    HWText(_constantLocalized),
  ],
);

WidgetSpec _spec(HWWidget tree) => WidgetSpec(
      data: HomeWidget(
        name: 'Greeting',
        widget: tree,
        android: const HomeWidgetAndroidConfiguration(
          packageName: 'com.example',
        ),
        iOS: const HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'Greeting',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.success(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);
  });

  /// Every file both native generators write for [spec], by path relative to
  /// the project root.
  Future<Map<String, String>> generateNative(WidgetSpec spec) async {
    final root = Directory.systemTemp.createTempSync('fixed_data_gen_test');
    addTearDown(() => root.deleteSync(recursive: true));
    writeRunnerXcodeProject(root);
    Directory(p.join(root.path, 'android', 'app')).createSync(recursive: true);

    await IosGenerator(spec: spec, projectRoot: root).generate();
    await AndroidGenerator(spec: spec, projectRoot: root).generate();

    return {
      for (final file in root.listSync(recursive: true).whereType<File>())
        p.relative(file.path, from: root.path): file.readAsStringSync(),
    };
  }

  group('fixed values next to a stored field', () {
    test('leave the Dart helper to the stored field alone', () {
      expect(
        DartHelperGenerator(_spec(_dataForms)).generate(),
        DartHelperGenerator(_spec(const HWText(HWString('label')))).generate(),
      );
    });

    test('are written into the native body as literals', () async {
      final files = await generateNative(_spec(_dataForms));

      final swift = files['ios/GreetingHomeWidget/Widget.swift']!;
      for (final line in [
        'Text("Hi")',
        'Text(hwFormatPercent(NSNumber(value: 3.0), minFraction: nil, '
            'maxFraction: nil))',
        'Text(hwFormatDecimal(NSNumber(value: 2.5), minFraction: nil, '
            'maxFraction: nil, grouping: true))',
        'Text(entry.data.label ?? "")',
      ]) {
        expect(swift, contains(line));
      }
      expect(
        RegExp(r'\(paramPrefix\)\.(\w+)')
            .allMatches(swift)
            .map((match) => match.group(1))
            .toSet(),
        {'label'},
      );

      final kotlin = files.entries
          .where((entry) => entry.key.endsWith('.kt'))
          .map((entry) => entry.value)
          .join('\n');
      expect(
        kotlin,
        contains('''
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = "Hi", style = TextStyle(color = GlanceTheme.colors.onSurface))
                    Text(text = hwFormatPercent(3.0, null, null, hwFormatLocale(context)), style = TextStyle(color = GlanceTheme.colors.onSurface))
                    Text(text = hwFormatDecimal(2.5, null, null, true, hwFormatLocale(context)), style = TextStyle(color = GlanceTheme.colors.onSurface))
                    Text(text = widgetData.label ?: "", style = TextStyle(color = GlanceTheme.colors.onSurface))
                }'''),
      );
      expect(
        RegExp(r'PREFERENCES_PREFIX\}\.(\w+)')
            .allMatches(kotlin)
            .map((match) => match.group(1))
            .toSet(),
        {'label'},
      );
    });
  });

  group('a schema of only fixed values', () {
    test('generates no saveData or getData parameter', () {
      final output = DartHelperGenerator(_spec(_onlyFixed)).generate();
      final empty = DartHelperGenerator(_spec(const HWText(_constantLocalized)))
          .generate();

      expect(output, empty);
      expect(output, isNot(contains('saveWidgetData')));
      expect(output, isNot(contains('getWidgetData')));
    });

    test('reads no storage key in the native code', () async {
      final files = await generateNative(_spec(_onlyFixed));

      final swift = files['ios/GreetingHomeWidget/Widget.swift']!;
      expect(swift, isNot(contains('fromUserDefaults')));
      expect(swift, isNot(contains('paramPrefix')));
      expect(swift, contains('Text("Hi")'));
      expect(swift, contains('Text("true")'));
      expect(swift, contains('hwParseIsoDate("2026-09-22T10:00:00.000Z")'));
      expect(swift, contains('func hwParseIsoDate('));

      final kotlin = files.entries
          .where((entry) => entry.key.endsWith('.kt'))
          .map((entry) => entry.value)
          .join('\n');
      expect(kotlin, isNot(contains('PREFERENCES_PREFIX')));
      expect(kotlin, isNot(contains('data class')));
      expect(kotlin, contains('text = "Hi"'));
      expect(kotlin, contains('text = "true"'));
      expect(kotlin, contains('hwParseIsoDate("2026-09-22T10:00:00.000Z")'));
      expect(kotlin, contains('fun hwParseIsoDate('));
    });
  });
}
