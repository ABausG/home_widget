import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('DartHelperGenerator', () {
    test('generates helper with data fields', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: [
          HWString('countLabel', defaultValue: 'Label'),
          HWInt('count', defaultValue: 0),
        ],
      );

      final generator = DartHelperGenerator(spec);
      final output = generator.generate();

      expect(output, contains('class ExampleWidgetHomeWidget {'));

      // saveData
      expect(output, contains('static Future<void> saveData({'));
      expect(output, contains('String? countLabel,'));
      expect(output, contains('int? count,'));
      expect(
        output,
        contains(
          "if (countLabel != null) HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.${'countLabel'}', countLabel),",
        ),
      );
      expect(
        output,
        contains(
          "if (count != null) HomeWidget.saveWidgetData<int>('\${_\$paramPrefix}.${'count'}', count),",
        ),
      );

      // deleteData
      expect(output, contains('static Future<void> deleteData({'));
      expect(output, contains('bool countLabel = false,'));
      expect(output, contains('bool count = false,'));
      expect(
        output,
        contains(
          "if (countLabel) HomeWidget.saveWidgetData('\${_\$paramPrefix}.${'countLabel'}', null),",
        ),
      );

      // getData
      expect(
        output,
        contains('static Future<({String? countLabel, int? count})> getData()'),
      );
      expect(
        output,
        contains(
          "countLabel: await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.${'countLabel'}', defaultValue: 'Label'),",
        ),
      );
      expect(
        output,
        contains(
          "count: await HomeWidget.getWidgetData<int>('\${_\$paramPrefix}.${'count'}', defaultValue: 0),",
        ),
      );
    });

    test('generates helper with JSON file groups', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [
          HWJson('fileKey', HWString('title')),
          HWJson('fileKey', HWBool('enabled', defaultValue: false)),
          HWJson('settings', HWBool('compact', defaultValue: true)),
        ],
      );

      final generator = DartHelperGenerator(spec);
      final output = generator.generate();

      expect(output, contains("import 'dart:convert';"));
      expect(output, contains("import 'dart:io';"));
      expect(output, contains("import 'dart:typed_data';"));
      expect(output, contains('FileKeyJsonData? fileKey,'));
      expect(output, contains('SettingsJsonData? settings,'));
      expect(
        output,
        contains(
          "await HomeWidget.saveFile('\${_\$paramPrefix}.fileKey', Uint8List.fromList(utf8.encode(jsonEncode(fileKey.toJson()))), extension: 'json');",
        ),
      );
      expect(
        output,
        isNot(
          contains(
            "await HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.fileKey'",
          ),
        ),
      );
      expect(
        output,
        contains(
          "final _fileKeyPath = await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.fileKey');",
        ),
      );
      expect(output, contains('FileKeyJsonData? fileKey;'));
      expect(output, contains('class FileKeyJsonData {'));
      expect(output, contains('final String? title;'));
      expect(output, contains('final bool? enabled;'));
      expect(output, contains('factory FileKeyJsonData.fromJson'));
      expect(output, contains('Map<String, dynamic> toJson()'));
      expect(output, contains("enabled: _readBool(json['enabled']) ?? false,"));
    });

    test('generates nested JSON data classes', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [
          HWJson('key', HWString('name', defaultValue: 'World')),
          HWJson(
            'key',
            HWJson(
              'greeting',
              HWString('greetingFormula', defaultValue: 'Hello'),
            ),
          ),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('KeyJsonData? key,'));
      expect(output, contains('class KeyJsonData {'));
      expect(output, contains('final String? name;'));
      expect(output, contains('final KeyGreetingJsonData? greeting;'));
      expect(output, contains('class KeyGreetingJsonData {'));
      expect(output, contains('final String? greetingFormula;'));
      expect(output, contains("name: _readString(json['name']) ?? 'World',"));
      expect(
        output,
        contains(
          "greeting: json['greeting'] is Map<String, dynamic> ? KeyGreetingJsonData.fromJson(json['greeting'] as Map<String, dynamic>) : null,",
        ),
      );
      expect(
        output,
        contains(
          "greetingFormula: _readString(json['greetingFormula']) ?? 'Hello',",
        ),
      );
    });

    test('generates updateWidget method', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final generator = DartHelperGenerator(spec);
      final output = generator.generate();

      expect(output, contains('static Future<bool?> updateWidget() {'));
      expect(
        output,
        contains(
          "androidName: 'com.example.ExampleWidgetHomeWidgetReceiver',",
        ),
      );
      expect(output, contains("iOSName: 'ExampleWidgetHomeWidget',"));
    });

    test('generates updateWidget method with default android name', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final generator = DartHelperGenerator(spec);
      final output = generator.generate();

      expect(output, contains('static Future<bool?> updateWidget() {'));
      // Should fallback to just receiver name if package is missing in annotation
      expect(
        output,
        contains("androidName: 'ExampleWidgetHomeWidgetReceiver',"),
      );
      expect(output, contains("iOSName: 'ExampleWidgetHomeWidget',"));
    });

    test('generates helper without data fields', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'NoDataWidget'),
        className: 'NoDataWidget',
        dataFields: [],
      );

      final generator = DartHelperGenerator(spec);
      final output = generator.generate();

      expect(output, contains('class NoDataWidgetHomeWidget {'));
      expect(output, isNot(contains('_\$paramPrefix')));
      expect(output, isNot(contains('saveData')));
      expect(output, isNot(contains('deleteData')));
      expect(output, isNot(contains('getData')));
    });

    test('passes appGroupId on data calls when iOS groupId is configured', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
        dataFields: [HWString('title')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains('ensureInitialized')));
      expect(
        output,
        contains("static const String _\$appGroupId = 'group.example';"),
      );
      expect(
        output,
        contains(
          "HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.title', title, appGroupId: _\$appGroupId)",
        ),
      );
      expect(
        output,
        contains(
          "HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.title', appGroupId: _\$appGroupId)",
        ),
      );
    });

    test('generates timed data class and saveData timedData branch', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
        ),
        className: 'ExampleWidget',
        dataFields: const [
          HWString('title'),
          HWTimedData(HWString('label', defaultValue: 'Sunny')),
          HWTimedData(HWInt('temperature')),
          HWTimedData(HWJson('weather', HWString('condition'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      // Timed data class
      expect(output, contains('class ExampleWidgetTimedData {'));
      expect(output, contains('final String? label;'));
      expect(output, contains('final int? temperature;'));
      expect(output, contains('final WeatherJsonData? weather;'));
      expect(output, contains('const ExampleWidgetTimedData({'));
      expect(
        output,
        contains('factory ExampleWidgetTimedData.fromJson('
            'Map<String, dynamic>? json) {'),
      );
      expect(output, contains("label: _readString(json['label']) ?? 'Sunny',"));
      expect(output, contains("temperature: _readInt(json['temperature']),"));
      expect(
        output,
        contains(
          "weather: json['weather'] is Map<String, dynamic> ? WeatherJsonData.fromJson(json['weather'] as Map<String, dynamic>) : null,",
        ),
      );
      expect(output, contains("if (label != null) 'label': label,"));
      expect(
        output,
        contains("if (weather != null) 'weather': weather!.toJson(),"),
      );

      // Nested JSON class for the timed HWJson root
      expect(output, contains('class WeatherJsonData {'));
      expect(output, contains('final String? condition;'));

      // JSON helper imports/readers are required for timed data too
      expect(output, contains("import 'dart:convert';"));
      expect(output, contains("import 'dart:io';"));
      expect(output, contains("import 'dart:typed_data';"));
      expect(output, contains('String? _readString(Object? value)'));
      expect(output, contains('int? _readInt(Object? value)'));

      // Only readers that are actually referenced are emitted, otherwise the
      // generated file trips the unused_element analyzer warning.
      expect(output, isNot(contains('_readDouble')));
      expect(output, isNot(contains('_readBool')));

      // saveData
      expect(
        output,
        contains('Map<DateTime, ExampleWidgetTimedData>? timedData,'),
      );
      expect(output, contains('if (timedData != null) () async {'));
      expect(
        output,
        contains('final _timedTimes = timedData.keys.toList()..sort();'),
      );
      expect(
        output,
        contains(
          "await HomeWidget.saveFile('\${_\$paramPrefix}.timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json');",
        ),
      );
      expect(
        output,
        contains(
          '_time.toUtc().millisecondsSinceEpoch.toString(): timedData[_time]!.toJson(),',
        ),
      );
      // Scheduling is a side effect and must never fail the data write.
      expect(
        output,
        contains(
          "        try {\n"
          "          await HomeWidget.scheduleWidgetUpdates(_timedTimes, androidName: 'com.example.ExampleWidgetHomeWidgetReceiver');\n"
          "        } catch (_) {\n",
        ),
      );
      // empty map clears the file and cancels the schedule
      expect(output, contains('if (_timedTimes.isEmpty) {'));
      expect(
        output,
        contains(
          "await HomeWidget.saveWidgetData('\${_\$paramPrefix}.timedData', null);",
        ),
      );
      expect(
        output,
        contains(
          "          try {\n"
          "            await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'com.example.ExampleWidgetHomeWidgetReceiver');\n"
          "          } catch (_) {\n",
        ),
      );

      // deleteData
      expect(output, contains('bool timedData = false,'));
      expect(output, contains('if (timedData) () async {'));
      expect(
        output,
        contains(
          "        try {\n"
          "          await HomeWidget.cancelScheduledWidgetUpdates(androidName: 'com.example.ExampleWidgetHomeWidgetReceiver');\n"
          "        } catch (_) {\n",
        ),
      );

      // getData
      expect(
        output,
        contains(
          '  /// The keys of [timedData] are local-time [DateTime]s, so they '
          'compare equal to a',
        ),
      );
      expect(
        output,
        contains(
          '  /// Keys are compared by instant, so a local [DateTime] and its '
          '`toUtc()` twin\n'
          '  /// denote the same entry and only one of them survives a save.',
        ),
      );
      expect(
        output,
        contains(
          'static Future<({String? title, Map<DateTime, ExampleWidgetTimedData>? timedData})> getData()',
        ),
      );
      expect(
        output,
        contains(
          "final _timedDataPath = await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.timedData');",
        ),
      );
      expect(
        output,
        contains('Map<DateTime, ExampleWidgetTimedData>? timedData;'),
      );
      expect(
        output,
        contains(
          'entries[DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal()] = ExampleWidgetTimedData.fromJson(value is Map<String, dynamic> ? value : null);',
        ),
      );
      expect(output, contains('timedData: timedData,'));
    });

    test('types a timed localized member as the translations class', () {
      const greeting = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'ExampleWidget',
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'ExampleWidget',
        dataFields: const [HWTimedData(greeting)],
      );

      final output = DartHelperGenerator(spec).generate();

      // A locale map, not the text of one unnamed locale.
      expect(
        output,
        contains(
          'final ExampleWidgetHomeWidgetTranslations? greeting;',
        ),
      );
      expect(
        output,
        contains("if (greeting != null) 'greeting': greeting!.toMap(),"),
      );
      // Reading an entry back merges it over the compiled defaults, exactly as
      // an untimed field does.
      expect(
        output,
        contains(
          "greeting: ExampleWidgetHomeWidget._\$mergeTranslations("
          'ExampleWidgetHomeWidget.greetingDefaults, '
          "_readTranslations(json['greeting'])),",
        ),
      );
      expect(output, contains('Map<String, String>? _readTranslations('));
      expect(
        output,
        contains('if (locale is String && text is String) '
            'values[locale] = text;'),
      );

      // The translations class and the compiled defaults ship for a timed-only
      // spec too...
      expect(output, contains('class ExampleWidgetHomeWidgetTranslations {'));
      expect(
        output,
        contains('static const ExampleWidgetHomeWidgetTranslations '
            'greetingDefaults ='),
      );
      // ...but nothing reads the field's own preferences key, so the blob
      // reader would be dead code.
      expect(output, isNot(contains(r'_$readLocalized')));
      expect(output, isNot(contains(r"'${_$paramPrefix}.greeting'")));
      // A timed member is never a `saveData` parameter of its own.
      expect(
        output,
        contains('static Future<void> saveData({\n'
            '    Map<DateTime, ExampleWidgetTimedData>? timedData,\n'
            '  }) {'),
      );
    });

    test('keeps a localized leaf of a timed JSON group a plain string', () {
      const summary = HWLocalizedString(
        'summary',
        defaultTranslations: {'en': 'Sunny', 'de': 'Sonnig'},
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'ExampleWidget',
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'ExampleWidget',
        dataFields: const [HWTimedData(HWJson('weather', summary))],
      );

      final output = DartHelperGenerator(spec).generate();

      // Same storage as an untimed leaf: the app pushes one string and the
      // compiled translations are the native fallback.
      expect(output, contains('final String? summary;'));
      expect(output, contains("summary: _readString(json['summary']),"));
      expect(output, isNot(contains('_readTranslations')));
      expect(output, isNot(contains('Translations? summary')));
    });

    test('passes appGroupId on timed data calls', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
        dataFields: const [HWTimedData(HWString('label'))],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          "await HomeWidget.saveFile('\${_\$paramPrefix}.timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json', appGroupId: _\$appGroupId);",
        ),
      );
      expect(
        output,
        contains(
          "final _timedDataPath = await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.timedData', appGroupId: _\$appGroupId);",
        ),
      );
      // Falls back to the bare receiver name when no package name is set
      expect(
        output,
        contains(
          "await HomeWidget.scheduleWidgetUpdates(_timedTimes, androidName: 'ExampleWidgetHomeWidgetReceiver');",
        ),
      );
    });

    test('omits timed data members when there are no timed fields', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [HWString('title')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains('TimedData')));
      expect(output, isNot(contains('timedData')));
      expect(output, isNot(contains('scheduleWidgetUpdates')));
      expect(output, isNot(contains('cancelScheduledWidgetUpdates')));
      expect(
        output,
        contains('static Future<void> saveData({\n    String? title,\n  }) {'),
      );
      expect(
        output,
        contains('static Future<({String? title})> getData() async {'),
      );
      expect(output, isNot(contains("import 'dart:convert';")));
    });

    test('omits appGroupId when iOS groupId is not configured', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: [HWString('title')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains('_\$appGroupId')));
      expect(output, isNot(contains('appGroupId:')));
    });
  });
}
