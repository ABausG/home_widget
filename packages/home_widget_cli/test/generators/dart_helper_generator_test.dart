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
      expect(output,
          contains("static const String _\$appGroupId = 'group.example';"));
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
