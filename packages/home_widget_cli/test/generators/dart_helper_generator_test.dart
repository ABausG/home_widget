import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
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

    test('emits the double reader for a numeric JSON leaf', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [
          HWJson('stats', HWDouble('progress', defaultValue: 0.5)),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'double? _readDouble(Object? value) => '
          'value is num ? value.toDouble() : null;',
        ),
      );
      expect(
        output,
        contains("progress: _readDouble(json['progress']) ?? 0.5,"),
      );
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

    test('generates image helpers for runtime images only', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Profile'),
        className: 'Profile',
        dataFields: const [
          HWString('title'),
          HWImageData('avatar'),
          HWImageData.asset('assets/logo.png'),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains("import 'package:flutter/widgets.dart';"));

      // saveData takes an ImageProvider for runtime images only.
      expect(output, contains('ImageProvider? avatar,'));
      expect(output, isNot(contains('ImageProvider? assetsLogoPng,')));
      expect(
        output,
        contains(
          '    final _rootImage_avatar = await _\$readImage(avatar);\n',
        ),
      );

      // Only a picture this widget wrote itself can be overwritten by the
      // call reading it, so only those are held in memory.
      expect(
        output,
        contains(r'''
  static Future<ImageProvider?> _$readImage(ImageProvider? image) async {
    if (image is! FileImage) return image;
    final path = image.file.path;
    final name = path.substring(path.lastIndexOf('/') + 1);
    if (!name.startsWith('${_$paramPrefix}.') || !name.endsWith('.png')) {
      return image;
    }
    try {
      return MemoryImage(await image.file.readAsBytes());
    } on FileSystemException {
      return null;
    }
  }
'''),
      );
      expect(
        output,
        contains(
          "if (_rootImage_avatar != null) _\$saveImage('\${_\$paramPrefix}.avatar', _rootImage_avatar),",
        ),
      );

      // No renderFlutterWidget convenience is generated; images are supplied
      // as ImageProviders through saveData.
      expect(output, isNot(contains('renderFlutterWidget')));

      // Asset images are read from the app bundle by native code, so they
      // never reach the Dart helper.
      expect(output, isNot(contains('AssetImage')));
      expect(output, isNot(contains('assetsLogoPng')));
      expect(output, contains('static Future<bool?> updateWidget() {'));

      // Runtime image paths still participate in getData as strings.
      expect(
        output,
        contains(
          'static Future<({String? title, String? avatar})> getData()',
        ),
      );
      expect(
        output,
        contains(
          "avatar: await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.avatar'),",
        ),
      );
      expect(output, contains('bool avatar = false,'));
      expect(
        output,
        contains(
          "if (avatar) HomeWidget.saveWidgetData('\${_\$paramPrefix}.avatar', null),",
        ),
      );
    });

    test('forwards appGroupId on image calls', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'Profile',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'Profile',
        dataFields: const [
          HWImageData('avatar'),
          HWImageData.asset('assets/logo.png'),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'final path = await HomeWidget.saveImage(key, image, '
          'appGroupId: _\$appGroupId);',
        ),
      );
    });

    test('emits no data plumbing when only asset images are declared', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'AssetOnly'),
        className: 'AssetOnly',
        dataFields: const [HWImageData.asset('assets/logo.png')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains('saveData(')));
      expect(output, isNot(contains('deleteData')));
      expect(output, isNot(contains('getData')));
      expect(output, isNot(contains("import 'package:flutter/widgets.dart';")));
      expect(output, contains('static Future<bool?> updateWidget() {'));
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
          "qualifiedAndroidName: 'com.example.ExampleWidgetHomeWidgetReceiver',",
        ),
      );
      expect(output, contains("iOSName: 'ExampleWidgetHomeWidget',"));
    });

    test('generates updatePreview naming the widget like updateWidget', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static Future<bool> updatePreview() async {\n'
          '    return await HomeWidget.updateWidgetPreview(\n'
          "      qualifiedAndroidName: 'com.example.ExampleWidgetHomeWidgetReceiver',\n"
          '    ) ?? false;\n'
          '  }',
        ),
      );
      // Sits directly after updateWidget, where a caller looks for it.
      expect(
        output.indexOf('updatePreview'),
        greaterThan(output.indexOf('updateWidget()')),
      );
      expect(
        output.indexOf('updatePreview'),
        lessThan(output.indexOf('isRequestPinWidgetSupported')),
      );
    });

    test('updatePreview falls back to the bare android name', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('HomeWidget.updateWidgetPreview('));
      expect(
        output,
        contains("androidName: 'ExampleWidgetHomeWidgetReceiver',"),
      );
    });

    test('updatePreview never names an iOS widget', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();
      final call = output.substring(
        output.indexOf('HomeWidget.updateWidgetPreview('),
      );

      // `updateWidget` right above it does name one, so only the preview call
      // is read here.
      expect(
        call.substring(0, call.indexOf(');')),
        isNot(contains('iOSName:')),
      );
    });

    test('no updatePreview for an iOS-only widget', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('static Future<bool?> updateWidget() {'));
      expect(output, isNot(contains('updatePreview')));
    });

    test('no updatePreview without any platform configuration', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('static Future<bool?> updateWidget() {'));
      expect(output, isNot(contains('updatePreview')));
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

    test('generates pin helpers with a qualified android name', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static Future<bool> isRequestPinWidgetSupported() async {\n'
          '    return await HomeWidget.isRequestPinWidgetSupported() ?? false;\n'
          '  }',
        ),
      );
      expect(
        output,
        contains(
          'static Future<void> requestPinWidget() {\n'
          '    return HomeWidget.requestPinWidget(\n'
          "      qualifiedAndroidName: 'com.example.ExampleWidgetHomeWidgetReceiver',\n"
          '    );\n'
          '  }',
        ),
      );
    });

    test('generates pin helpers with the default android name', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static Future<void> requestPinWidget() {\n'
          '    return HomeWidget.requestPinWidget(\n'
          "      androidName: 'ExampleWidgetHomeWidgetReceiver',\n"
          '    );\n'
          '  }',
        ),
      );
    });

    test('omits the pin helpers without an android configuration', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains('requestPinWidget')));
      expect(output, isNot(contains('isRequestPinWidgetSupported')));
    });

    test('generates install helpers matching both platforms', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static Future<List<HomeWidgetInfo>> getInstalledWidgets() async {\n'
          '    final widgets = await HomeWidget.getInstalledWidgets();\n'
          '    return widgets.where(_\$isThisWidget).toList();\n'
          '  }',
        ),
      );
      expect(
        output,
        contains(
          'static Future<bool> isInstalled() async {\n'
          '    return (await getInstalledWidgets()).isNotEmpty;\n'
          '  }',
        ),
      );
      expect(
        output,
        contains(
          'static bool _\$isThisWidget(HomeWidgetInfo info) {\n'
          '    final androidClassName = info.androidClassName;\n'
          '    if (androidClassName != null) {\n'
          "      return androidClassName.endsWith('.ExampleWidgetHomeWidgetReceiver');\n"
          '    }\n'
          "    return info.iOSKind == 'ExampleWidgetHomeWidget';\n"
          '  }',
        ),
      );
    });

    test('matches nothing on iOS without an iOS configuration', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static bool _\$isThisWidget(HomeWidgetInfo info) {\n'
          '    final androidClassName = info.androidClassName;\n'
          '    if (androidClassName != null) {\n'
          "      return androidClassName.endsWith('.ExampleWidgetHomeWidgetReceiver');\n"
          '    }\n'
          '    return false;\n'
          '  }',
        ),
      );
    });

    test('matches nothing on Android without an android configuration', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static bool _\$isThisWidget(HomeWidgetInfo info) {\n'
          '    final androidClassName = info.androidClassName;\n'
          '    if (androidClassName != null) {\n'
          '      return false;\n'
          '    }\n'
          "    return info.iOSKind == 'ExampleWidgetHomeWidget';\n"
          '  }',
        ),
      );
    });

    test('generates the install helpers for a bare widget', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'PlainWidget'),
        className: 'PlainWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('getInstalledWidgets()'));
      expect(output, contains('static Future<bool> isInstalled() async {'));
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

      // JSON helper imports/readers are required for timed data too. Timed
      // data also pulls in `flutter/foundation.dart` (for FlutterError
      // reporting in the scheduling guard), which already re-exports
      // `dart:typed_data`, so the plain import would be flagged as unused.
      expect(output, contains("import 'dart:convert';"));
      expect(output, contains("import 'dart:io';"));
      expect(output, isNot(contains("import 'dart:typed_data';")));
      expect(output, contains("import 'package:flutter/foundation.dart';"));
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
      // Scheduling is a side effect and must never fail the data write, but a
      // genuine misconfiguration is still reported instead of swallowed.
      expect(
        output,
        contains(
          "        try {\n"
          "          await HomeWidget.scheduleWidgetUpdates(_timedTimes, qualifiedAndroidName: 'com.example.ExampleWidgetHomeWidgetReceiver');\n"
          "        } catch (error, stackTrace) {\n"
          "          // Scheduling is best effort; the data was saved.\n"
          "          FlutterError.reportError(\n"
          "            FlutterErrorDetails(\n"
          "              exception: error,\n"
          "              stack: stackTrace,\n"
          "              library: 'home_widget',\n"
          "              context: ErrorDescription('scheduling updates for the ExampleWidget widget'),\n"
          "            ),\n"
          "          );\n"
          "        }\n",
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
          "            await HomeWidget.cancelScheduledWidgetUpdates(qualifiedAndroidName: 'com.example.ExampleWidgetHomeWidgetReceiver');\n"
          "          } catch (error, stackTrace) {\n"
          "            // Cancelling is best effort; the data was deleted.\n"
          "            FlutterError.reportError(\n"
          "              FlutterErrorDetails(\n"
          "                exception: error,\n"
          "                stack: stackTrace,\n"
          "                library: 'home_widget',\n"
          "                context: ErrorDescription('cancelling scheduled updates for the ExampleWidget widget'),\n"
          "              ),\n"
          "            );\n"
          "          }\n",
        ),
      );

      // deleteData
      expect(output, contains('bool timedData = false,'));
      expect(output, contains('if (timedData) () async {'));
      expect(
        output,
        contains(
          "        try {\n"
          "          await HomeWidget.cancelScheduledWidgetUpdates(qualifiedAndroidName: 'com.example.ExampleWidgetHomeWidgetReceiver');\n"
          "        } catch (error, stackTrace) {\n"
          "          // Cancelling is best effort; the data was deleted.\n"
          "          FlutterError.reportError(\n"
          "            FlutterErrorDetails(\n"
          "              exception: error,\n"
          "              stack: stackTrace,\n"
          "              library: 'home_widget',\n"
          "              context: ErrorDescription('cancelling scheduled updates for the ExampleWidget widget'),\n"
          "            ),\n"
          "          );\n"
          "        }\n",
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

    test('saves and clears images at JSON leaves', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
        dataFields: const [
          HWJson('contact', HWString('name')),
          HWJson('contact', HWImageData('avatar')),
          HWJson('contact', HWJson('photos', HWImageData('main'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      // The leaf carries the provider itself and never serializes it.
      expect(output, contains('final ImageProvider? avatar;'));
      expect(output, contains("import 'package:flutter/widgets.dart';"));
      expect(output, contains("avatar: _readFileImage(json['avatar']),"));
      expect(output, isNot(contains("if (avatar != null) 'avatar': avatar,")));
      expect(output, contains("if (name != null) 'name': name,"));

      // Root leaf: saved into the blob under a key derived from the path.
      expect(
        output,
        contains(
          'final _jsonImage_contact_avatar = '
          'await _\$readImage(contact?.avatar);',
        ),
      );
      expect(
        output,
        contains(
          "_contactJson['avatar'] = await _\$saveImage("
          "'\${_\$paramPrefix}.contact.avatar', _jsonImage_contact_avatar);",
        ),
      );
      // A missing image writes nothing into the blob and drops the PNG.
      expect(
        output,
        contains(
          '} else {\n'
          "          await HomeWidget.saveWidgetData<String>('"
          "\${_\$paramPrefix}.contact.avatar', null, "
          'appGroupId: _\$appGroupId);',
        ),
      );
      // Nested leaf: the ancestor map is there because the object chain was.
      expect(
        output,
        contains(
          'final _jsonImage_contact_photos_main = '
          'await _\$readImage(contact?.photos?.main);',
        ),
      );
      expect(
        output,
        contains(
          "(_contactJson['photos']! as Map<String, dynamic>)['main'] = "
          "await _\$saveImage('"
          "\${_\$paramPrefix}.contact.photos.main', "
          '_jsonImage_contact_photos_main);',
        ),
      );
      // Images are written before the blob that has to carry their paths.
      expect(
        output.indexOf(r'_$saveImage('),
        lessThan(output.indexOf('HomeWidget.saveFile(')),
      );

      // deleteData drops the blob and every PNG the group owns.
      expect(
        output,
        contains(
          '      if (contact) () async {\n'
          "        await HomeWidget.saveWidgetData('\${_\$paramPrefix}.contact', null, appGroupId: _\$appGroupId);\n"
          "        await HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.contact.avatar', null, appGroupId: _\$appGroupId);\n"
          "        await HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.contact.photos.main', null, appGroupId: _\$appGroupId);",
        ),
      );
      // Untimed leaves have stable keys, so there is nothing to prune.
      expect(output, isNot(contains(r'_$deleteTimedImages')));
    });

    test('keys a JSON leaf image of a timed group by timestamp', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [
          HWTimedData(HWJson('slot', HWImageData('picture'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          '          _time: await _\$readImage(_entry.slot?.picture),\n',
        ),
      );
      expect(
        output,
        contains(
          'final _jsonImage_slot_picture = '
          '_timedJsonImages_slot_picture[_time];',
        ),
      );
      expect(
        output,
        contains(
          "(_values['slot']! as Map<String, dynamic>)['picture'] = "
          "await _\$saveImage('"
          "\${_\$paramPrefix}.timedData.slot.picture.\$_millis', "
          '_jsonImage_slot_picture);',
        ),
      );
      // Pruning covers a JSON leaf exactly like a root timed image.
      expect(output, contains("for (final _key in const ['slot.picture'])"));
      expect(
        output,
        contains(
          r'await _$deleteTimedImages(_storedTimes.where((_millis) => '
          '!_timedJson.containsKey(_millis.toString())));',
        ),
      );
    });

    test('gives colliding timed and JSON leaf images distinct locals', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [
          HWTimedData(HWImageData('contactAvatar')),
          HWTimedData(HWJson('contact', HWImageData('avatar'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'final _timedImage_contactAvatar = '
          '_timedImages_contactAvatar[_time];',
        ),
      );
      expect(
        output,
        contains(
          'final _jsonImage_contact_avatar = '
          '_timedJsonImages_contact_avatar[_time];',
        ),
      );
    });

    test('gives colliding JSON leaf paths distinct locals', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [
          HWJson('media', HWImageData('photoSet')),
          HWJson('media', HWJson('photo', HWImageData('set'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'final _jsonImage_media_photoSet = '
          'await _\$readImage(media?.photoSet);',
        ),
      );
      expect(
        output,
        contains(
          'final _jsonImage_media_photo_set = '
          'await _\$readImage(media?.photo?.set);',
        ),
      );
    });

    test('saves, records and prunes per-timestamp images', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
        dataFields: const [
          HWTimedData(HWImageData('slide')),
          HWTimedData(HWString('caption')),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      // The entry carries the provider itself, not a path.
      expect(output, contains('final ImageProvider? slide;'));
      expect(output, contains("import 'package:flutter/widgets.dart';"));
      // ...and never serializes it: only saveData knows where the PNG went.
      expect(output, isNot(contains("'slide': slide,")));
      expect(output, contains("if (caption != null) 'caption': caption,"));
      expect(output, contains("slide: _readFileImage(json['slide']),"));
      expect(output, contains('ImageProvider? _readFileImage(Object? value)'));
      expect(
        output,
        contains('return file.existsSync() ? FileImage(file) : null;'),
      );

      // The stale keys are read before anything is written, every image is
      // saved into the entry, and only then is the timeline written and the
      // images of dropped timestamps deleted.
      final storedAt =
          output.indexOf(r'final _storedTimes = await _$storedTimedKeys();');
      final saveImageAt = output.indexOf(r'await _$saveImage(');
      final saveFileAt = output.indexOf('HomeWidget.saveFile(');
      final deleteAt =
          output.indexOf(r'await _$deleteTimedImages(_storedTimes.where(');
      expect(storedAt, greaterThan(-1));
      expect(saveImageAt, greaterThan(storedAt));
      expect(saveFileAt, greaterThan(saveImageAt));
      expect(deleteAt, greaterThan(saveFileAt));

      expect(
        output,
        contains(
          "_values['slide'] = await _\$saveImage("
          "'\${_\$paramPrefix}.timedData.slide.\$_millis', _timedImage_slide);",
        ),
      );
      // A slot that survives but loses its image drops the old PNG too.
      expect(
        output,
        contains(
          '} else if (_storedTimes.contains(_millis)) {\n'
          "            await HomeWidget.saveWidgetData<String>('"
          "\${_\$paramPrefix}.timedData.slide.\$_millis', null, "
          'appGroupId: _\$appGroupId);',
        ),
      );
      expect(
        output,
        contains(
          r'await _$deleteTimedImages(_storedTimes.where((_millis) => '
          '!_timedJson.containsKey(_millis.toString())));',
        ),
      );

      // Cleanup helpers: the stored timeline is the only record of which
      // images exist, and clearing a key deletes its PNG with it.
      expect(
        output,
        contains(r'static Future<List<int>> _$storedTimedKeys() async {'),
      );
      expect(
        output,
        contains("for (final _key in const ['slide'])"),
      );
      expect(
        output,
        contains(
          "HomeWidget.saveWidgetData<String>("
          "'\${_\$paramPrefix}.timedData.\$_key.\$_millis', null, "
          'appGroupId: _\$appGroupId),',
        ),
      );

      // deleteData drops the schedule together with all of its images.
      expect(
        output,
        contains(
          '      if (timedData) () async {\n'
          '        final _storedTimes = await _\$storedTimedKeys();\n'
          "        await HomeWidget.saveWidgetData('\${_\$paramPrefix}.timedData', null, appGroupId: _\$appGroupId);\n"
          '        await _\$deleteTimedImages(_storedTimes);',
        ),
      );
    });

    test('leaves the timed save path untouched without timed images', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: const [HWTimedData(HWString('label'))],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains(r'_$storedTimedKeys')));
      expect(output, isNot(contains(r'_$deleteTimedImages')));
      expect(output, isNot(contains('_readFileImage')));
      expect(output, contains('final _timedJson = <String, dynamic>{\n'));
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

    test('resolves the appGroupId per flavor when flavors are declared', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
          flavors: const {
            'dev': HomeWidgetFlavor(
              iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
            ),
            'prod': HomeWidgetFlavor(),
          },
        ),
        className: 'ExampleWidget',
        dataFields: [HWString('title')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains("import 'package:flutter/services.dart';"));
      expect(
        output,
        contains(
          'static String get _\$appGroupId => switch (appFlavor) {\n'
          "    'dev' => 'group.example.dev',\n"
          "    'prod' => 'group.example',\n"
          "    _ => 'group.example',\n"
          '  };',
        ),
      );
      expect(
        output,
        isNot(contains("static const String _\$appGroupId = 'group.example';")),
      );
      expect(
        output,
        contains(
          "HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.title', title, appGroupId: _\$appGroupId)",
        ),
      );

      // `// dart format off` keeps the emitted switch exactly as written, so
      // format it again without the marker to prove it is valid Dart.
      final formatted = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(output.replaceFirst('// dart format off\n', ''));
      expect(formatted, contains('switch (appFlavor)'));
    });

    test('keeps the appGroupId constant when no flavors are declared', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
        dataFields: [HWString('title')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains("static const String _\$appGroupId = 'group.example';"),
      );
      expect(output, isNot(contains('appFlavor')));
      expect(
        output,
        isNot(contains("import 'package:flutter/services.dart';")),
      );
    });

    test('emits the launch helpers when a widget URL is configured', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'LinkedWidget',
          widgetUrl: 'myapp://linked',
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'LinkedWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains('static Future<Uri?> initiallyLaunchedFromWidget() async {'),
      );
      expect(
        output,
        contains(
          'static Stream<Uri> get widgetClicked =>\n'
          '      HomeWidget.widgetClicked\n'
          '          .where((uri) => uri != null && _\$matchesWidgetUrl(uri))\n'
          '          .cast<Uri>();',
        ),
      );
      expect(
        output,
        contains('static Stream<Uri> launchedFromWidget() async* {'),
      );
      expect(
        output,
        contains(
          'final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();',
        ),
      );
      expect(
        output,
        contains(
          'if (initial != null && _\$matchesWidgetUrl(initial)) yield initial;',
        ),
      );
      expect(output, contains('yield* clicks.stream;'));
      expect(output, isNot(contains('where:')));
      expect(output, isNot(contains('widgetClickedWhere')));
    });

    test('exposes the runtime widget URL and filters the streams by it', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'LinkedWidget',
          widgetUrl: 'myApp://linked',
          android: HomeWidgetAndroidConfiguration(),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'LinkedWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          "static final Uri widgetUrl = Uri.parse('myApp://linked?homeWidget');",
        ),
      );
      expect(output, contains('as the app'));
      expect(output, contains('/// will receive it.'));
      expect(output, isNot(contains('androidWidgetUrl')));
      expect(output, isNot(contains('iosWidgetUrl')));
      expect(
        output,
        contains(
          'static bool _\$matchesWidgetUrl(Uri uri) {\n'
          '    final url = _\$platformWidgetUrl;\n'
          '    if (url == null) return false;\n'
          '    return _\$lowerCaseScheme(uri) == _\$lowerCaseScheme(url);\n'
          '  }',
        ),
      );
      expect(
        output,
        contains(
          'static Uri? get _\$platformWidgetUrl {\n'
          '    if (Platform.isAndroid) return widgetUrl;\n'
          '    if (Platform.isIOS) return widgetUrl;\n'
          '    return null;\n'
          '  }',
        ),
      );
      expect(output, contains("import 'dart:io';"));
      expect(
        output,
        contains(
          'static String _\$lowerCaseScheme(Uri uri) {\n'
          '    final text = uri.toString();\n'
          '    return uri.scheme.toLowerCase() + text.substring(uri.scheme.length);\n'
          '  }',
        ),
      );
    });

    test('exposes one runtime URL per platform when they differ', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'Split',
          widgetUrl: 'myapp://shared',
          android: HomeWidgetAndroidConfiguration(
            widgetUrl: 'myapp://android',
          ),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'Split',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static final Uri androidWidgetUrl = '
          "Uri.parse('myapp://android?homeWidget');",
        ),
      );
      expect(
        output,
        contains(
          'static final Uri iosWidgetUrl = '
          "Uri.parse('myapp://shared?homeWidget');",
        ),
      );
      expect(
        output,
        contains(
          'static Uri? get _\$platformWidgetUrl {\n'
          '    if (Platform.isAndroid) return androidWidgetUrl;\n'
          '    if (Platform.isIOS) return iosWidgetUrl;\n'
          '    return null;\n'
          '  }',
        ),
      );
      expect(output, contains('opens the app with on Android'));
      expect(output, contains('opens the app with on iOS'));
    });

    test('subscribes to the click stream before awaiting the launch URL', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'LinkedWidget',
          widgetUrl: 'myapp://linked',
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'LinkedWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      final subscribeAt = output.indexOf(
        'final subscription = HomeWidget.widgetClicked.listen(',
      );
      final awaitAt = output.indexOf(
        'final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();',
      );

      expect(subscribeAt, greaterThan(-1));
      expect(awaitAt, greaterThan(subscribeAt));
      expect(output, contains('final clicks = StreamController<Uri>();'));
      expect(output, contains("import 'dart:async';"));
      expect(output, contains('await subscription.cancel();'));
    });

    test('emits the launch helpers for a platform-only widget URL', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'AndroidOnly',
          android: HomeWidgetAndroidConfiguration(
            widgetUrl: 'myapp://android',
          ),
        ),
        className: 'AndroidOnly',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains('static Future<Uri?> initiallyLaunchedFromWidget() async {'),
      );
      expect(
        output,
        contains(
          'static final Uri androidWidgetUrl = '
          "Uri.parse('myapp://android?homeWidget');",
        ),
      );
      expect(output, isNot(contains('iosWidgetUrl')));
      expect(
        output,
        contains(
          'static Uri? get _\$platformWidgetUrl {\n'
          '    if (Platform.isAndroid) return androidWidgetUrl;\n'
          '    return null;\n'
          '  }',
        ),
      );
      expect(
        output,
        contains('/// Nothing is ever reported on iOS, where the widget opens'),
      );
    });

    test('keeps a top-level widget URL off iOS without an iOS configuration',
        () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'NoIos',
          widgetUrl: 'myapp://shared',
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'NoIos',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static final Uri androidWidgetUrl = '
          "Uri.parse('myapp://shared?homeWidget');",
        ),
      );
      expect(output, isNot(contains('iosWidgetUrl')));
      expect(
        output,
        contains(
          'static Uri? get _\$platformWidgetUrl {\n'
          '    if (Platform.isAndroid) return androidWidgetUrl;\n'
          '    return null;\n'
          '  }',
        ),
      );
      expect(
        output,
        contains('/// Nothing is ever reported on iOS, where the widget opens'),
      );
    });

    test(
        'keeps a top-level widget URL off Android without an Android '
        'configuration', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'NoAndroid',
          widgetUrl: 'myapp://shared',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'NoAndroid',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          'static final Uri iosWidgetUrl = '
          "Uri.parse('myapp://shared?homeWidget');",
        ),
      );
      expect(output, isNot(contains('androidWidgetUrl')));
      expect(
        output,
        contains(
          'static Uri? get _\$platformWidgetUrl {\n'
          '    if (Platform.isIOS) return iosWidgetUrl;\n'
          '    return null;\n'
          '  }',
        ),
      );
      expect(
        output,
        contains(
          '/// Nothing is ever reported on Android, where the widget opens',
        ),
      );
    });

    test('omits the launch helpers without a widget URL', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'PlainWidget'),
        className: 'PlainWidget',
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, isNot(contains('initiallyLaunchedFromWidget')));
      expect(output, isNot(contains('widgetClicked')));
      expect(output, isNot(contains('launchedFromWidget')));
    });

    test('stores a top-level date as a UTC ISO string', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'Agenda',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.agenda'),
        ),
        className: 'Agenda',
        dataFields: const [HWDateTime('lastSync')],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('DateTime? lastSync,'));
      expect(
        output,
        contains(
          "if (lastSync != null) HomeWidget.saveWidgetData<String>('\${_\$paramPrefix}.lastSync', lastSync.toUtc().toIso8601String(), appGroupId: _\$appGroupId),",
        ),
      );
      // The delete path is untyped and clears the key like any other field.
      expect(
        output,
        contains(
          "if (lastSync) HomeWidget.saveWidgetData('\${_\$paramPrefix}.lastSync', null, appGroupId: _\$appGroupId),",
        ),
      );
      expect(
        output,
        contains('static Future<({DateTime? lastSync})> getData()'),
      );
      expect(
        output,
        contains(
          "lastSync: _readDateTime(await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.lastSync', appGroupId: _\$appGroupId)),",
        ),
      );
      expect(
        output,
        contains(
          'DateTime? _readDateTime(Object? value) {\n'
          '  if (value is! String || value.isEmpty) return null;\n'
          '  return DateTime.tryParse(value)?.toUtc();\n'
          '}',
        ),
      );
      // A date needs no JSON plumbing of its own.
      expect(output, isNot(contains("import 'dart:convert';")));
      expect(output, isNot(contains('_readString')));
    });

    test('encodes a date at a JSON leaf as a UTC ISO string', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Agenda'),
        className: 'Agenda',
        dataFields: const [
          HWJson('event', HWString('title')),
          HWJson('event', HWJson('slot', HWDateTime('startsAt'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('class EventSlotJsonData {'));
      expect(output, contains('final DateTime? startsAt;'));
      expect(output, contains("startsAt: _readDateTime(json['startsAt']),"));
      expect(
        output,
        contains(
          "if (startsAt != null) 'startsAt': startsAt!.toUtc().toIso8601String(),",
        ),
      );
      expect(output, contains('DateTime? _readDateTime(Object? value) {'));
    });

    test('encodes a timed date as a UTC ISO string', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Agenda'),
        className: 'Agenda',
        dataFields: const [
          HWTimedData(HWDateTime('slot')),
          HWTimedData(HWJson('shift', HWDateTime('endsAt'))),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      // Timed primitive
      expect(output, contains('class AgendaTimedData {'));
      expect(output, contains('final DateTime? slot;'));
      expect(output, contains("slot: _readDateTime(json['slot']),"));
      expect(
        output,
        contains("if (slot != null) 'slot': slot!.toUtc().toIso8601String(),"),
      );

      // Timed JSON leaf, which reuses the plain JSON data class
      expect(output, contains('class ShiftJsonData {'));
      expect(output, contains('final DateTime? endsAt;'));
      expect(output, contains("endsAt: _readDateTime(json['endsAt']),"));
      expect(
        output,
        contains(
          "if (endsAt != null) 'endsAt': endsAt!.toUtc().toIso8601String(),",
        ),
      );
    });

    test('round-trips a date through the generated JSON class', () async {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Agenda'),
        className: 'Agenda',
        dataFields: const [HWJson('event', HWDateTime('startsAt'))],
      );

      final output = await _runGenerated(
        DartHelperGenerator(spec).generate(),
        'class EventJsonData',
        '''
  final local = DateTime(2026, 1, 2, 3, 4, 5, 6);
  final encoded = EventJsonData(startsAt: local).toJson();
  print(encoded['startsAt']);
  print(encoded['startsAt'] == local.toUtc().toIso8601String());
  final decoded = EventJsonData.fromJson(encoded);
  print(decoded.startsAt!.isAtSameMomentAs(local));
  print(decoded.startsAt!.isUtc);
  print(EventJsonData.fromJson({'startsAt': 'not a date'}).startsAt);
  print(EventJsonData.fromJson(const {}).toJson());
''',
      );

      expect(
        const LineSplitter().convert(output),
        [
          // A local time is stored as the instant it denotes, in UTC.
          endsWith('Z'),
          'true',
          'true',
          'true',
          // Anything unreadable comes back absent rather than throwing.
          'null',
          '{}',
        ],
      );
    });

    test('emits an enum for a top-level icon and stores its codepoint', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [_mood],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains("import 'package:flutter/widgets.dart';"));
      expect(output, contains('enum ForecastMoodIcon {'));
      expect(
        output,
        contains(
          "wbSunny(IconData(0xe2bd, fontFamily: 'MaterialIcons', "
          'fontPackage: null)),',
        ),
      );
      expect(
        output,
        contains(
          "cloud(IconData(0xe2bf, fontFamily: 'MaterialIcons', "
          'fontPackage: null));',
        ),
      );
      expect(output, contains('const ForecastMoodIcon(this.icon);'));
      expect(output, contains('final IconData icon;'));
      expect(output, contains('int get codePoint => icon.codePoint;'));
      expect(
        output,
        contains('static ForecastMoodIcon? fromCodePoint(int? codePoint) {'),
      );
      expect(output, contains('if (codePoint == null) return null;'));
      expect(
        output,
        contains('if (value.codePoint == codePoint) return value;'),
      );

      // saveData takes the enum and writes the codepoint as an int, exactly
      // the way an HWInt field is written.
      expect(output, contains('ForecastMoodIcon? mood,'));
      expect(
        output,
        contains(
          "if (mood != null) HomeWidget.saveWidgetData<int>('\${_\$paramPrefix}.mood', mood.codePoint),",
        ),
      );

      // getData hands the enum back, falling back on the declared default.
      expect(
        output,
        contains('static Future<({ForecastMoodIcon? mood})> getData()'),
      );
      expect(
        output,
        contains(
          "mood: ForecastMoodIcon.fromCodePoint(await HomeWidget.getWidgetData<int>('\${_\$paramPrefix}.mood', defaultValue: 0xe2bd)),",
        ),
      );

      // Clearing an icon is clearing its key, like any other value.
      expect(output, contains('bool mood = false,'));
      expect(
        output,
        contains(
          "if (mood) HomeWidget.saveWidgetData('\${_\$paramPrefix}.mood', null),",
        ),
      );
    });

    test('names the package an icon font comes from', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [
          HWIconData.resolved(
            'mood',
            entries: [HWIconEntry('sunMax', 0xf4b6)],
            iconFont: HWIconFont(
              family: 'CupertinoIcons',
              package: 'cupertino_icons',
            ),
          ),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          "sunMax(IconData(0xf4b6, fontFamily: 'CupertinoIcons', "
          "fontPackage: 'cupertino_icons'));",
        ),
      );
    });

    test('keeps matchTextDirection on a directional icon', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [
          HWIconData.resolved(
            'arrow',
            entries: [
              HWIconEntry('arrowBack', 0xe5c4, matchTextDirection: true),
              HWIconEntry('cloud', 0xe2bf),
            ],
            iconFont: _materialIcons,
          ),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(
        output,
        contains(
          "arrowBack(IconData(0xe5c4, fontFamily: 'MaterialIcons', "
          'fontPackage: null, matchTextDirection: true)),',
        ),
      );
      expect(
        output,
        contains(
          "cloud(IconData(0xe2bf, fontFamily: 'MaterialIcons', "
          'fontPackage: null));',
        ),
      );
    });

    test('emits one enum per key, not per declaration', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [_mood, _mood],
      );

      final output = DartHelperGenerator(spec).generate();

      expect('enum ForecastMoodIcon {'.allMatches(output), hasLength(1));
      expect('ForecastMoodIcon? mood,'.allMatches(output), hasLength(1));
    });

    test('merges two fields that land on one enum name', () {
      const morning = HWIconData.resolved(
        'icon',
        entries: [HWIconEntry('wbSunny', 0xe2bd), HWIconEntry('cloud', 0xe2bf)],
        iconFont: _materialIcons,
      );
      const evening = HWIconData.resolved(
        'icon',
        entries: [HWIconEntry('rain', 0xe2c1), HWIconEntry('snow', 0xe2c3)],
        iconFont: _materialIcons,
      );
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [
          HWJson('today', morning),
          HWJson('tomorrow', evening),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect('enum ForecastIconIcon {'.allMatches(output), hasLength(1));
      for (final name in ['wbSunny', 'cloud', 'rain', 'snow']) {
        expect(output, contains('  $name(IconData(0x'));
      }
      expect(output, contains('final ForecastIconIcon? icon;'));
      expect(
        "icon: ForecastIconIcon.fromCodePoint(_readInt(json['icon'])),"
            .allMatches(output),
        hasLength(2),
      );
    });

    test('rejects two fields whose shared enum disagrees', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [
          HWJson('today', _mood),
          HWJson(
            'tomorrow',
            HWIconData.resolved(
              'mood',
              entries: [HWIconEntry('wbSunny', 0xe999)],
              iconFont: _materialIcons,
            ),
          ),
        ],
      );

      expect(
        () => DartHelperGenerator(spec).generate(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('"today.mood"'), contains('"tomorrow.mood"')),
          ),
        ),
      );
    });

    test('carries an icon through a JSON group as the enum', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [
          HWJson('day', _condition),
          HWJson('day', HWString('label')),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('enum ForecastConditionIcon {'));
      expect(output, contains('class DayJsonData {'));
      expect(output, contains('final ForecastConditionIcon? condition;'));
      expect(
        output,
        contains(
          "condition: ForecastConditionIcon.fromCodePoint(_readInt(json['condition']) ?? 0xe2bf),",
        ),
      );
      expect(
        output,
        contains("if (condition != null) 'condition': condition!.codePoint,"),
      );
      expect(output, contains('int? _readInt(Object? value)'));
    });

    test('carries an icon through a timed entry as the enum', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'Forecast'),
        className: 'Forecast',
        dataFields: const [
          HWTimedData(_slot),
          HWTimedData(HWJson('shift', _condition)),
        ],
      );

      final output = DartHelperGenerator(spec).generate();

      expect(output, contains('enum ForecastSlotIcon {'));
      expect(output, contains('enum ForecastConditionIcon {'));

      // Timed primitive
      expect(output, contains('class ForecastTimedData {'));
      expect(output, contains('final ForecastSlotIcon? slot;'));
      expect(
        output,
        contains(
          "slot: ForecastSlotIcon.fromCodePoint(_readInt(json['slot'])),",
        ),
      );
      expect(output, contains("if (slot != null) 'slot': slot!.codePoint,"));

      // Timed JSON leaf, which reuses the plain JSON data class
      expect(output, contains('class ShiftJsonData {'));
      expect(output, contains('final ForecastConditionIcon? condition;'));
      expect(
        output,
        contains(
          "condition: ForecastConditionIcon.fromCodePoint(_readInt(json['condition']) ?? 0xe2bf),",
        ),
      );
      expect(
        output,
        contains("if (condition != null) 'condition': condition!.codePoint,"),
      );
    });
  });

  group('DartHelperGenerator lists', () {
    test('saves, deletes and reads a list as its only data', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
        ),
      ).generate();

      expect(output, contains("import 'dart:convert';"));
      expect(output, contains("import 'dart:io';"));
      expect(output, contains("import 'dart:typed_data';"));
      expect(output, contains("import 'package:flutter/widgets.dart';"));
      expect(
        output,
        contains("static const String _\$appGroupId = 'group.weather';"),
      );

      expect(
        output,
        contains(
          '  static Future<void> saveData({\n'
          '    List<WeatherForecastItem>? forecast,\n'
          '  }) {',
        ),
      );
      expect(
        output,
        contains(
          '      if (forecast != null) () async {\n'
          "        await HomeWidget.saveFile('\${_\$paramPrefix}.forecast', "
          'Uint8List.fromList(utf8.encode(jsonEncode([for (final _item in '
          "forecast) _item.toJson()]))), extension: 'json', "
          'appGroupId: _\$appGroupId);\n'
          '      }(),',
        ),
      );

      expect(output, contains('    bool forecast = false,\n'));
      expect(
        output,
        contains(
          "      if (forecast) HomeWidget.saveWidgetData('\${_\$paramPrefix}"
          ".forecast', null, appGroupId: _\$appGroupId),",
        ),
      );

      expect(
        output,
        contains(
          'static Future<({List<WeatherForecastItem>? forecast})> getData() '
          'async {',
        ),
      );
      expect(
        output,
        contains('''
    final _forecastPath = await HomeWidget.getWidgetData<String>('\${_\$paramPrefix}.forecast', appGroupId: _\$appGroupId);
    List<WeatherForecastItem>? forecast;
    if (_forecastPath != null) {
      try {
        final _forecastJson = jsonDecode(await File(_forecastPath).readAsString());
        if (_forecastJson is List) forecast = [for (final _item in _forecastJson) WeatherForecastItem.fromJson(_item is Map<String, dynamic> ? _item : null)];
      } on Exception {
        forecast = null;
      }
    }
'''),
      );
      expect(output, contains('      forecast: forecast,\n'));
    });

    test('shapes the item class like a JSON group, defaults applied', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
        ),
      ).generate();

      expect(
        output,
        contains('''
class WeatherForecastItem {
  final DateTime? day;
  final WeatherConditionIcon? condition;
  final int? temperature;
  final double? rain;
  final bool? windy;
  final String? note;

  const WeatherForecastItem({
    this.day,
    this.condition,
    this.temperature,
    this.rain,
    this.windy,
    this.note,
  });

  factory WeatherForecastItem.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return WeatherForecastItem(
      day: _readDateTime(json['day']),
      condition: WeatherConditionIcon.fromCodePoint(_readInt(json['condition']) ?? 0xe2bd),
      temperature: _readInt(json['temperature']) ?? 0,
      rain: _readDouble(json['rain']),
      windy: _readBool(json['windy']) ?? false,
      note: _readString(json['note']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (day != null) 'day': day!.toUtc().toIso8601String(),
      if (condition != null) 'condition': condition!.codePoint,
      if (temperature != null) 'temperature': temperature,
      if (rain != null) 'rain': rain,
      if (windy != null) 'windy': windy,
      if (note != null) 'note': note,
    };
  }
}
'''),
      );
      expect(output, contains('enum WeatherConditionIcon {'));
      for (final reader in [
        'String? _readString(',
        'int? _readInt(',
        'double? _readDouble(',
        'bool? _readBool(',
        'DateTime? _readDateTime(',
      ]) {
        expect(output, contains(reader));
      }
    });

    test('puts the list after the root fields it is saved beside', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn(
            children: [
              HWText(HWString('unit', defaultValue: '°C')),
              HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
            ],
          ),
        ),
      ).generate();

      expect(
        output,
        contains(
          '    String? unit,\n'
          '    List<WeatherForecastItem>? forecast,\n',
        ),
      );
      expect(
        output,
        contains('    bool unit = false,\n    bool forecast = false,\n'),
      );
      expect(
        output,
        contains(
          'static Future<({String? unit, List<WeatherForecastItem>? '
          'forecast})> getData()',
        ),
      );
    });

    test('gives several builders over one list one class and one parameter',
        () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWSizeAdaptive(
            small: HWRow.builder(
              'forecast',
              maxItems: 3,
              item: HWText(HWItemData(HWString('label'))),
            ),
            large: HWColumn.builder(
              'forecast',
              maxItems: 6,
              item: HWText.number(HWItemData(HWInt('temperature'))),
            ),
          ),
        ),
      ).generate();

      expect('class WeatherForecastItem {'.allMatches(output), hasLength(1));
      expect(output, contains('  final String? label;\n'));
      expect(output, contains('  final int? temperature;\n'));
      expect(
        'List<WeatherForecastItem>? forecast,'.allMatches(output),
        hasLength(1),
      );
    });

    test('gives every list a class and a parameter of its own', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn(
            children: [
              HWRow.builder(
                'forecast',
                maxItems: 3,
                item: HWText(HWItemData(HWString('label'))),
              ),
              HWColumn.builder(
                'events',
                maxItems: 2,
                item: HWText(HWItemData(HWString('title'))),
              ),
            ],
          ),
        ),
      ).generate();

      expect(output, contains('class WeatherForecastItem {'));
      expect(output, contains('class WeatherEventsItem {'));
      expect(
        output,
        contains(
          '    List<WeatherForecastItem>? forecast,\n'
          '    List<WeatherEventsItem>? events,\n',
        ),
      );
      expect(
        output,
        contains(
          'static Future<({List<WeatherForecastItem>? forecast, '
          'List<WeatherEventsItem>? events})> getData()',
        ),
      );
    });

    test('shares one enum between an item icon and a root icon of its key', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn(
            children: [
              HWIcon(
                HWIconData.resolved(
                  'condition',
                  entries: [HWIconEntry('rain', 0xe2c1)],
                  iconFont: _materialIcons,
                ),
              ),
              HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
            ],
          ),
        ),
      ).generate();

      expect('enum WeatherConditionIcon {'.allMatches(output), hasLength(1));
      for (final name in ['rain', 'wbSunny', 'cloud']) {
        expect(output, contains('  $name(IconData(0x'));
      }
      expect(output, contains('    WeatherConditionIcon? condition,\n'));
      expect(output, contains('  final WeatherConditionIcon? condition;\n'));
    });

    test('keeps a localized item field a plain string', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWRow.builder(
            'forecast',
            maxItems: 5,
            item: HWText(
              HWItemData(
                HWString.localized(
                  'label',
                  defaultTranslations: {'en': 'Day', 'de': 'Tag'},
                  previewTranslations: {'en': 'Monday'},
                ),
              ),
            ),
          ),
        ),
      ).generate();

      expect(output, contains('  final String? label;\n'));
      expect(output, contains("      label: _readString(json['label']),\n"));
      expect(output, contains("      if (label != null) 'label': label,\n"));
      expect(output, isNot(contains('Translations')));
    });

    test('gives an item that reads no field a class without members', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWRow.builder('dots', maxItems: 3, item: HWText.fixed('.')),
        ),
      ).generate();

      expect(
        output,
        contains('''
class WeatherDotsItem {
  const WeatherDotsItem();

  factory WeatherDotsItem.fromJson(Map<String, dynamic>? json) {'''),
      );
      expect(output, contains('    List<WeatherDotsItem>? dots,\n'));
    });

    test('carries a time-based list in every timed entry, not in saveData', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn(
            children: [
              HWText(HWString('city')),
              HWText(HWTimedData(HWString('summary'))),
              HWColumn.builder('hourly', maxItems: 4, item: _hourlyItem),
              HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
            ],
          ),
        ),
      ).generate();

      expect(
        output,
        contains('''
class WeatherTimedData {
  final String? summary;
  final List<WeatherHourlyItem>? hourly;

  const WeatherTimedData({
    this.summary,
    this.hourly,
  });

  factory WeatherTimedData.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return WeatherTimedData(
      summary: _readString(json['summary']),
      hourly: json['hourly'] is List ? [for (final _e in json['hourly'] as List) WeatherHourlyItem.fromJson(_e is Map<String, dynamic> ? _e : null)] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (summary != null) 'summary': summary,
      if (hourly != null) 'hourly': [for (final _e in hourly!) _e.toJson()],
    };
  }
}
'''),
      );
      expect(output, contains('class WeatherHourlyItem {'));
      expect(output, contains('class WeatherForecastItem {'));
      expect(
        output,
        contains(
          '  static Future<void> saveData({\n'
          '    String? city,\n'
          '    List<WeatherForecastItem>? forecast,\n'
          '    Map<DateTime, WeatherTimedData>? timedData,\n'
          '  }) {',
        ),
      );
      expect(
        output,
        contains(
          '    bool city = false,\n'
          '    bool forecast = false,\n'
          '    bool timedData = false,\n',
        ),
      );
      expect(
        output,
        contains(
          'static Future<({String? city, List<WeatherForecastItem>? forecast, '
          'Map<DateTime, WeatherTimedData>? timedData})> getData()',
        ),
      );
    });

    test('saves, reads and deletes a time-based list as the only timed data',
        () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn.builder('hourly', maxItems: 4, item: _hourlyItem),
        ),
      ).generate();

      expect(output, contains("import 'dart:convert';"));
      expect(output, contains("import 'dart:io';"));
      expect(output, contains("import 'package:flutter/foundation.dart';"));
      expect(output, isNot(contains("import 'dart:typed_data';")));
      expect(output, isNot(contains("import 'package:flutter/widgets.dart';")));
      expect(
        output,
        contains(
          '  static Future<void> saveData({\n'
          '    Map<DateTime, WeatherTimedData>? timedData,\n'
          '  }) {',
        ),
      );
      expect(
        output,
        contains(
          '_time.toUtc().millisecondsSinceEpoch.toString(): '
          'timedData[_time]!.toJson(),',
        ),
      );
      expect(
        output,
        contains(
          'await HomeWidget.scheduleWidgetUpdates(_timedTimes, '
          "androidName: 'WeatherHomeWidgetReceiver');",
        ),
      );
      expect(output, contains('    bool timedData = false,\n'));
      expect(
        output,
        contains(
          'await HomeWidget.cancelScheduledWidgetUpdates('
          "androidName: 'WeatherHomeWidgetReceiver');",
        ),
      );
      expect(
        output,
        contains(
          'static Future<({Map<DateTime, WeatherTimedData>? timedData})> '
          'getData() async {',
        ),
      );
      expect(output, contains('  final List<WeatherHourlyItem>? hourly;\n'));
      for (final reader in [
        'String? _readString(',
        'int? _readInt(',
        'DateTime? _readDateTime(',
      ]) {
        expect(output, contains(reader));
      }
      expect(output, isNot(contains('_\$storedTimedListLengths')));
      expect(output, isNot(contains('_\$deleteListImages')));
    });

    test('round-trips every kind of item field', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWRow.builder('forecast', maxItems: 1, item: _forecastItem),
          ),
        ).generate(),
        r'''
  await WeatherHomeWidget.saveData(
    forecast: [
      WeatherForecastItem(
        day: DateTime.utc(2026, 9, 21, 12),
        condition: WeatherConditionIcon.cloud,
        temperature: 21,
        rain: 0.5,
        windy: true,
        note: 'Sunny spells',
      ),
      const WeatherForecastItem(),
    ],
  );
  print(File(HomeWidget.data['home_widget.Weather.forecast'] as String).readAsStringSync());
  final forecast = (await WeatherHomeWidget.getData()).forecast!;
  print(forecast.length);
  print(forecast.first.day!.isAtSameMomentAs(DateTime.utc(2026, 9, 21, 12)));
  print(forecast.first.condition);
  for (final item in forecast) {
    print(item.toJson());
  }
''',
      );

      expect(const LineSplitter().convert(output), [
        '[{"day":"2026-09-21T12:00:00.000Z","condition":58047,'
            '"temperature":21,"rain":0.5,"windy":true,"note":"Sunny spells"},'
            '{}]',
        // Every item is stored, however few a builder renders.
        '2',
        'true',
        'WeatherConditionIcon.cloud',
        '{day: 2026-09-21T12:00:00.000Z, condition: 58047, temperature: 21, '
            'rain: 0.5, windy: true, note: Sunny spells}',
        // A field an item was saved without reads back as its default.
        '{condition: 58045, temperature: 0, windy: false}',
      ]);
    });

    test('tells nothing saved, an empty list and a deleted one apart',
        () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn(
              children: [
                HWText(HWString('unit')),
                HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
              ],
            ),
          ),
        ).generate(),
        r'''
  print((await WeatherHomeWidget.getData()).forecast);
  await WeatherHomeWidget.saveData(forecast: const []);
  print((await WeatherHomeWidget.getData()).forecast);
  await WeatherHomeWidget.saveData(unit: '°F');
  print((await WeatherHomeWidget.getData()).forecast);
  await WeatherHomeWidget.deleteData(forecast: true);
  print((await WeatherHomeWidget.getData()).forecast);
  print(HomeWidget.data.keys.toList());
''',
      );

      expect(const LineSplitter().convert(output), [
        'null',
        '[]',
        // Saving another field leaves the list as it was.
        '[]',
        'null',
        '[home_widget.Weather.unit]',
      ]);
    });

    test('reads anything but a JSON array back as no list', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
          ),
        ).generate(),
        r'''
  final file = File('${HomeWidget.directory.path}/stored.json');
  HomeWidget.data['home_widget.Weather.forecast'] = file.path;
  for (final content in ['{"temperature": 3}', '42', 'not json']) {
    file.writeAsStringSync(content);
    print((await WeatherHomeWidget.getData()).forecast);
  }
  file.deleteSync();
  print((await WeatherHomeWidget.getData()).forecast);
''',
      );

      expect(const LineSplitter().convert(output), [
        'null',
        'null',
        'null',
        'null',
      ]);
    });

    test('reads an element that is no JSON object as an item storing nothing',
        () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
          ),
        ).generate(),
        r'''
  final file = File('${HomeWidget.directory.path}/stored.json');
  file.writeAsStringSync('[{"temperature": 3}, 42, null, "rain"]');
  HomeWidget.data['home_widget.Weather.forecast'] = file.path;
  for (final item in (await WeatherHomeWidget.getData()).forecast!) {
    print(item.toJson());
  }
''',
      );

      expect(const LineSplitter().convert(output), [
        '{condition: 58045, temperature: 3, windy: false}',
        '{condition: 58045, temperature: 0, windy: false}',
        '{condition: 58045, temperature: 0, windy: false}',
        '{condition: 58045, temperature: 0, windy: false}',
      ]);
    });

    test('round-trips a list whose item reads no field', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWRow.builder('dots', maxItems: 3, item: HWText.fixed('.')),
          ),
        ).generate(),
        r'''
  await WeatherHomeWidget.saveData(
    dots: const [WeatherDotsItem(), WeatherDotsItem()],
  );
  print(File(HomeWidget.data['home_widget.Weather.dots'] as String).readAsStringSync());
  print((await WeatherHomeWidget.getData()).dots!.length);
''',
      );

      expect(const LineSplitter().convert(output), ['[{},{}]', '2']);
    });

    test('saves the images of every item to a PNG each, keyed by its index',
        () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
        ),
      ).generate();

      expect(output, contains("import 'package:flutter/widgets.dart';"));
      // Every item's pictures are read before the first of them is written,
      // so an item that moved keeps the one it came with.
      expect(
        output,
        contains(r'''
    final _itemImages_contacts_avatar = [
      if (contacts != null)
        for (final _item in contacts) await _$readImage(_item.avatar),
    ];
    final _itemImages_contacts_badge = [
      if (contacts != null)
        for (final _item in contacts) await _$readImage(_item.badge),
    ];
    await Future.wait([
'''),
      );
      expect(
        output,
        contains(r'''
      if (contacts != null) () async {
        final _storedLength = await _$storedListLength('${_$paramPrefix}.contacts');
        final _listJson = <Map<String, dynamic>>[];
        for (var _index = 0; _index < contacts.length; _index++) {
          final _item = contacts[_index];
          final _values = _item.toJson();
          final _itemImage_avatar = _itemImages_contacts_avatar[_index];
          if (_itemImage_avatar != null) {
            _values['avatar'] = await _$saveImage('${_$paramPrefix}.contacts.$_index.avatar', _itemImage_avatar);
          } else if (_index < _storedLength) {
            await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.contacts.$_index.avatar', null, appGroupId: _$appGroupId);
          }
          final _itemImage_badge = _itemImages_contacts_badge[_index];
          if (_itemImage_badge != null) {
            _values['badge'] = await _$saveImage('${_$paramPrefix}.contacts.$_index.badge', _itemImage_badge);
          } else if (_index < _storedLength) {
            await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.contacts.$_index.badge', null, appGroupId: _$appGroupId);
          }
          _listJson.add(_values);
        }
        await HomeWidget.saveFile('${_$paramPrefix}.contacts', Uint8List.fromList(utf8.encode(jsonEncode(_listJson))), extension: 'json', appGroupId: _$appGroupId);
        await _$deleteListImages('${_$paramPrefix}.contacts', const ['avatar', 'badge'], contacts.length, _storedLength);
      }(),
'''),
      );
      expect(
        output,
        contains(r'''
      if (contacts) () async {
        final _storedLength = await _$storedListLength('${_$paramPrefix}.contacts');
        await HomeWidget.saveWidgetData('${_$paramPrefix}.contacts', null, appGroupId: _$appGroupId);
        await _$deleteListImages('${_$paramPrefix}.contacts', const ['avatar', 'badge'], 0, _storedLength);
      }(),
'''),
      );
      expect(
        output,
        contains(r'''
  static Future<int> _$storedListLength(String key) async {
    final path = await HomeWidget.getWidgetData<String>(key, appGroupId: _$appGroupId);
    if (path == null) return 0;
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      return decoded is List ? decoded.length : 0;
    } on Exception {
      return 0;
    }
  }

  static Future<void> _$deleteListImages(
    String key,
    List<String> fields,
    int from,
    int to,
  ) async {
    await Future.wait([
      for (var index = from; index < to; index++)
        for (final field in fields)
          HomeWidget.saveWidgetData<String>('$key.$index.$field', null, appGroupId: _$appGroupId),
    ]);
  }
'''),
      );
      expect(output, contains('  final ImageProvider? avatar;\n'));
      expect(
        output,
        contains("      avatar: _readFileImage(json['avatar']),\n"),
      );
      expect(output, contains('ImageProvider? _readFileImage(Object? value)'));
    });

    test('keeps a list without images a single write beside one with them', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn(
            children: [
              HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
              HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
            ],
          ),
        ),
      ).generate();

      expect(
        output,
        contains(
          "        await HomeWidget.saveFile('\${_\$paramPrefix}.forecast', "
          'Uint8List.fromList(utf8.encode(jsonEncode([for (final _item in '
          "forecast) _item.toJson()]))), extension: 'json', "
          'appGroupId: _\$appGroupId);\n',
        ),
      );
      expect(
        output,
        contains(
          "      if (forecast) HomeWidget.saveWidgetData('\${_\$paramPrefix}"
          ".forecast', null, appGroupId: _\$appGroupId),",
        ),
      );
      expect(
        'static Future<int> _\$storedListLength('.allMatches(output),
        hasLength(1),
      );
    });

    test('emits no list image helpers for lists without images', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWRow.builder('forecast', maxItems: 5, item: _forecastItem),
        ),
      ).generate();

      expect(output, isNot(contains('_\$storedListLength')));
      expect(output, isNot(contains('_\$deleteListImages')));
    });

    test('round-trips item images through a PNG per item', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
          ),
        ).generate(),
        r'''
  String shown(Object? value) =>
      '$value'.replaceAll(HomeWidget.directory.path, '<dir>');
  await WeatherHomeWidget.saveData(
    contacts: [
      WeatherContactsItem(
        name: 'Ada',
        avatar: MemoryImage(utf8.encode('ada')),
        badge: MemoryImage(utf8.encode('star')),
      ),
      const WeatherContactsItem(name: 'Bob'),
      WeatherContactsItem(name: 'Cy', avatar: MemoryImage(utf8.encode('cy'))),
    ],
  );
  print(shown(File(HomeWidget.data['home_widget.Weather.contacts'] as String).readAsStringSync()));
  print(HomeWidget.data.keys.toList()..sort());
  for (final item in (await WeatherHomeWidget.getData()).contacts!) {
    final avatar = item.avatar;
    final badge = item.badge;
    print([
      item.name,
      avatar is FileImage ? avatar.file.readAsStringSync() : avatar,
      badge is FileImage ? badge.file.readAsStringSync() : badge,
    ]);
  }
''',
      );

      expect(const LineSplitter().convert(output), [
        '[{"name":"Ada","avatar":"<dir>/home_widget.Weather.contacts.0.avatar.png",'
            '"badge":"<dir>/home_widget.Weather.contacts.0.badge.png"},'
            '{"name":"Bob"},'
            '{"name":"Cy","avatar":"<dir>/home_widget.Weather.contacts.2.avatar.png"}]',
        '[home_widget.Weather.contacts, home_widget.Weather.contacts.0.avatar, '
            'home_widget.Weather.contacts.0.badge, '
            'home_widget.Weather.contacts.2.avatar]',
        '[Ada, ada, star]',
        '[Bob, null, null]',
        '[Cy, cy, null]',
      ]);
    });

    test('keeps every item image when the list is reordered', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
          ),
        ).generate(),
        r'''
  Future<List<String>> avatars() async => [
        for (final item in (await WeatherHomeWidget.getData()).contacts!)
          switch (item.avatar) {
            FileImage(:final file) => file.readAsStringSync(),
            _ => '<none>',
          },
      ];
  Future<void> save(List<WeatherContactsItem> contacts) =>
      WeatherHomeWidget.saveData(contacts: contacts);

  await save([
    WeatherContactsItem(name: 'a', avatar: MemoryImage(utf8.encode('A'))),
    WeatherContactsItem(name: 'b', avatar: MemoryImage(utf8.encode('B'))),
  ]);
  print(await avatars());

  // A new item in front of the ones getData handed back: every stored item
  // moves up one index, onto the file the item before it was read from.
  await save([
    WeatherContactsItem(name: 'c', avatar: MemoryImage(utf8.encode('C'))),
    ...(await WeatherHomeWidget.getData()).contacts!,
  ]);
  print(await avatars());

  // Two items trading places read each other's file.
  final stored = (await WeatherHomeWidget.getData()).contacts!;
  await save([stored[1], stored[0], stored[2]]);
  print(await avatars());

  // ...and the same list saved again is unchanged.
  await save((await WeatherHomeWidget.getData()).contacts!);
  print(await avatars());
''',
      );

      expect(const LineSplitter().convert(output), [
        '[A, B]',
        '[C, A, B]',
        '[A, C, B]',
        '[A, C, B]',
      ]);
    });

    test('leaves a picture no write of the call can replace unread', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
          ),
        ).generate(),
        r'''
  final brought = FileImage(
    File('${HomeWidget.directory.path}/photo.png')..writeAsStringSync('pic'),
  );
  print(identical(await WeatherHomeWidget._$readImage(brought), brought));

  final gone = FileImage(File('${HomeWidget.directory.path}/gone.png'));
  print(identical(await WeatherHomeWidget._$readImage(gone), gone));

  await WeatherHomeWidget.saveData(
    contacts: [WeatherContactsItem(name: 'Ada', avatar: brought)],
  );
  final stored = (await WeatherHomeWidget.getData()).contacts!.single.avatar!;
  print(await WeatherHomeWidget._$readImage(stored) is MemoryImage);
  print((stored as FileImage).file.readAsStringSync());
''',
      );

      expect(const LineSplitter().convert(output), [
        'true',
        'true',
        'true',
        'pic',
      ]);
    });

    test('saves every other field when an item image file is gone', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn(
              children: [
                HWText(HWString('title')),
                HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
              ],
            ),
          ),
        ).generate(),
        r'''
  await WeatherHomeWidget.saveData(
    title: 'Team',
    contacts: [
      WeatherContactsItem(name: 'Ada', avatar: MemoryImage(utf8.encode('ada'))),
      WeatherContactsItem(name: 'Bob', avatar: MemoryImage(utf8.encode('bob'))),
    ],
  );
  final stored = (await WeatherHomeWidget.getData()).contacts!;
  File(HomeWidget.data['home_widget.Weather.contacts.0.avatar'] as String)
      .deleteSync();

  await WeatherHomeWidget.saveData(title: 'Crew', contacts: stored);
  final data = await WeatherHomeWidget.getData();
  print(data.title);
  for (final item in data.contacts!) {
    final avatar = item.avatar;
    print([
      item.name,
      avatar is FileImage ? avatar.file.readAsStringSync() : avatar,
    ]);
  }
''',
      );

      expect(const LineSplitter().convert(output), [
        'Crew',
        '[Ada, null]',
        '[Bob, bob]',
      ]);
    });

    test('keeps every entry image when the timeline shifts', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn(
              children: [
                HWImage(HWTimedData(HWImageData('hero'))),
                HWColumn.builder('slides', maxItems: 3, item: _slideItem),
              ],
            ),
          ),
        ).generate(),
        r'''
  final morning = DateTime.utc(2026, 9, 21, 6);
  final noon = DateTime.utc(2026, 9, 21, 12);
  String shown(ImageProvider? image) => switch (image) {
        FileImage(:final file) => file.readAsStringSync(),
        _ => '<none>',
      };
  Future<List<Object>> timeline() async {
    final data = (await WeatherHomeWidget.getData()).timedData!;
    return [
      for (final time in data.keys.toList()..sort())
        [
          shown(data[time]!.hero),
          [for (final slide in data[time]!.slides!) shown(slide.photo)],
        ],
    ];
  }

  await WeatherHomeWidget.saveData(
    timedData: {
      morning: WeatherTimedData(
        hero: MemoryImage(utf8.encode('dawn')),
        slides: [
          WeatherSlidesItem(caption: 'a', photo: MemoryImage(utf8.encode('A'))),
        ],
      ),
      noon: WeatherTimedData(
        hero: MemoryImage(utf8.encode('midday')),
        slides: [
          WeatherSlidesItem(caption: 'b', photo: MemoryImage(utf8.encode('B'))),
        ],
      ),
    },
  );
  print(await timeline());

  // The timeline shifts one slot up: what noon shows moves to morning, whose
  // own pictures are written first. getData hands the instants back in local
  // time, so the stored entries are taken by the keys it used.
  final stored = (await WeatherHomeWidget.getData()).timedData!;
  final times = stored.keys.toList()..sort();
  await WeatherHomeWidget.saveData(
    timedData: {times[0]: stored[times[1]]!, times[1]: stored[times[0]]!},
  );
  print(await timeline());
''',
      );

      expect(const LineSplitter().convert(output), [
        '[[dawn, [A]], [midday, [B]]]',
        '[[midday, [B]], [dawn, [A]]]',
      ]);
    });

    test('deletes the images of the items a shorter list no longer has',
        () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
          ),
        ).generate(),
        r'''
  List<String> files() => [
        for (final file in HomeWidget.directory.listSync())
          file.path.split('/').last,
      ]..sort();
  await WeatherHomeWidget.saveData(
    contacts: [
      for (final name in ['ada', 'bob', 'cy'])
        WeatherContactsItem(
          name: name,
          avatar: MemoryImage(utf8.encode(name)),
          badge: MemoryImage(utf8.encode('$name badge')),
        ),
    ],
  );
  await WeatherHomeWidget.saveData(
    contacts: [
      const WeatherContactsItem(name: 'ada'),
      WeatherContactsItem(name: 'bob', avatar: MemoryImage(utf8.encode('bob 2'))),
    ],
  );
  print(files());
  print(HomeWidget.data.keys.toList()..sort());
  final contacts = (await WeatherHomeWidget.getData()).contacts!;
  print((contacts[1].avatar as FileImage).file.readAsStringSync());
  await WeatherHomeWidget.saveData(contacts: const []);
  print(files());
  print((await WeatherHomeWidget.getData()).contacts);
''',
      );

      expect(const LineSplitter().convert(output), [
        '[home_widget.Weather.contacts.1.avatar.png, '
            'home_widget.Weather.contacts.json]',
        '[home_widget.Weather.contacts, '
            'home_widget.Weather.contacts.1.avatar]',
        'bob 2',
        '[home_widget.Weather.contacts.json]',
        '[]',
      ]);
    });

    test('deletes a list together with the images of its items', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn(
              children: [
                HWText(HWString('title')),
                HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
              ],
            ),
          ),
        ).generate(),
        r'''
  await WeatherHomeWidget.saveData(
    title: 'Team',
    contacts: [
      WeatherContactsItem(name: 'Ada', avatar: MemoryImage(utf8.encode('ada'))),
      WeatherContactsItem(name: 'Bob', badge: MemoryImage(utf8.encode('bob'))),
    ],
  );
  await WeatherHomeWidget.deleteData(contacts: true);
  print(HomeWidget.data.keys.toList());
  print(HomeWidget.directory.listSync());
  print((await WeatherHomeWidget.getData()).contacts);
  await WeatherHomeWidget.deleteData(contacts: true);
  print(HomeWidget.data.keys.toList());
''',
      );

      expect(const LineSplitter().convert(output), [
        '[home_widget.Weather.title]',
        '[]',
        'null',
        '[home_widget.Weather.title]',
      ]);
    });

    test('reads an item image whose file is gone as no image', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
          ),
        ).generate(),
        r'''
  await WeatherHomeWidget.saveData(
    contacts: [
      WeatherContactsItem(name: 'Ada', avatar: MemoryImage(utf8.encode('ada'))),
    ],
  );
  File(HomeWidget.data['home_widget.Weather.contacts.0.avatar'] as String).deleteSync();
  print((await WeatherHomeWidget.getData()).contacts!.single.avatar);
''',
      );

      expect(output, 'null');
    });

    test('saves over a stored list it cannot read', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
          ),
        ).generate(),
        r'''
  final file = File('${HomeWidget.directory.path}/stored.json');
  for (final content in ['not json', '{"name": "Ada"}']) {
    file.writeAsStringSync(content);
    HomeWidget.data['home_widget.Weather.contacts'] = file.path;
    await WeatherHomeWidget.saveData(
      contacts: [
        WeatherContactsItem(name: 'Ada', avatar: MemoryImage(utf8.encode('ada'))),
      ],
    );
    print((await WeatherHomeWidget.getData()).contacts!.single.name);
  }
''',
      );

      expect(const LineSplitter().convert(output), ['Ada', 'Ada']);
    });

    test('round-trips a timeline whose every entry carries a list of its own',
        () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn(
              children: [
                HWText(HWTimedData(HWString('summary'))),
                HWColumn.builder('hourly', maxItems: 2, item: _hourlyItem),
              ],
            ),
          ),
        ).generate(),
        r'''
  final morning = DateTime.utc(2026, 9, 21, 6);
  final noon = DateTime.utc(2026, 9, 21, 12);
  final evening = DateTime.utc(2026, 9, 21, 18);
  await WeatherHomeWidget.saveData(
    timedData: {
      noon: const WeatherTimedData(
        hourly: [
          WeatherHourlyItem(temperature: 21),
          WeatherHourlyItem(temperature: 22),
          WeatherHourlyItem(temperature: 20),
        ],
      ),
      morning: WeatherTimedData(
        summary: 'Fog',
        hourly: [
          WeatherHourlyItem(
            time: DateTime.utc(2026, 9, 21, 7),
            temperature: 12,
            note: 'Chilly',
          ),
          const WeatherHourlyItem(),
        ],
      ),
      evening: const WeatherTimedData(summary: 'Clear'),
    },
  );
  print(File(HomeWidget.data['home_widget.Weather.timedData'] as String).readAsStringSync());
  print(HomeWidget.schedule);
  final timedData = (await WeatherHomeWidget.getData()).timedData!;
  for (final time in [morning, noon, evening]) {
    print(timedData[time.toLocal()]!.hourly?.map((item) => item.toJson()).toList());
  }
  print(timedData[morning.toLocal()]!.hourly!.first.time!.isAtSameMomentAs(DateTime.utc(2026, 9, 21, 7)));
  await WeatherHomeWidget.deleteData(timedData: true);
  print((await WeatherHomeWidget.getData()).timedData);
  print(HomeWidget.schedule);
''',
      );

      final morning = DateTime.utc(2026, 9, 21, 6).millisecondsSinceEpoch;
      final noon = DateTime.utc(2026, 9, 21, 12).millisecondsSinceEpoch;
      final evening = DateTime.utc(2026, 9, 21, 18).millisecondsSinceEpoch;
      expect(const LineSplitter().convert(output), [
        '{"$morning":{"summary":"Fog","hourly":['
            '{"time":"2026-09-21T07:00:00.000Z","temperature":12,'
            '"note":"Chilly"},{}]},'
            '"$noon":{"hourly":[{"temperature":21},{"temperature":22},'
            '{"temperature":20}]},'
            '"$evening":{"summary":"Clear"}}',
        '[2026-09-21 06:00:00.000Z, 2026-09-21 12:00:00.000Z, '
            '2026-09-21 18:00:00.000Z]',
        '[{time: 2026-09-21T07:00:00.000Z, temperature: 12, note: Chilly}, '
            '{temperature: 0}]',
        '[{temperature: 21}, {temperature: 22}, {temperature: 20}]',
        // An entry saved without the list reads back without one.
        'null',
        'true',
        'null',
        'null',
      ]);
    });

    test('reads a timed list that is no JSON array back as no list', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('hourly', maxItems: 4, item: _hourlyItem),
          ),
        ).generate(),
        r'''
  final file = File('${HomeWidget.directory.path}/stored.json');
  file.writeAsStringSync('{"1000": {"hourly": {"temperature": 3}}, "2000": {"hourly": [{"temperature": 3}, 42]}}');
  HomeWidget.data['home_widget.Weather.timedData'] = file.path;
  final timedData = (await WeatherHomeWidget.getData()).timedData!;
  for (final millis in [1000, 2000]) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    print(timedData[time]!.hourly?.map((item) => item.toJson()).toList());
  }
''',
      );

      expect(const LineSplitter().convert(output), [
        'null',
        '[{temperature: 3}, {temperature: 0}]',
      ]);
    });

    test('saves the item images of every timed entry keyed by index and time',
        () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn.builder('slides', maxItems: 3, item: _slideItem),
        ),
      ).generate();

      expect(output, contains("import 'package:flutter/widgets.dart';"));
      // The whole timeline's pictures are read before the first write, so an
      // entry that shifted keeps the one it came with.
      expect(
        output,
        contains(r'''
    final _timedItemImages_slides_photo = {
      if (timedData != null)
        for (final MapEntry(key: _time, value: _entry) in timedData.entries)
          _time: [
            for (final _item in _entry.slides ?? const [])
              await _$readImage(_item.photo),
          ],
    };
    await Future.wait([
'''),
      );
      expect(
        output,
        contains(r'''
        final _timedTimes = timedData.keys.toList()..sort();
        final _storedLengths = await _$storedTimedListLengths();
        if (_timedTimes.isEmpty) {
          await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
          await _$deleteTimedListImages(_storedLengths, _storedLengths.keys);
'''),
      );
      expect(
        output,
        contains(r'''
          final _values = _entry.toJson();
          if (_entry.slides case final _items?) {
            final _itemsJson = _values['slides'] as List<Map<String, dynamic>>;
            for (var _index = 0; _index < _items.length; _index++) {
              final _item = _items[_index];
              final _itemImage_photo = _timedItemImages_slides_photo[_time]![_index];
              if (_itemImage_photo != null) {
                _itemsJson[_index]['photo'] = await _$saveImage('${_$paramPrefix}.timedData.slides.$_index.photo.$_millis', _itemImage_photo);
              } else if (_index < (_storedLengths[_millis]?['slides'] ?? 0)) {
                await HomeWidget.saveWidgetData<String>('${_$paramPrefix}.timedData.slides.$_index.photo.$_millis', null, appGroupId: _$appGroupId);
              }
            }
          }
          await _$deleteListImages('${_$paramPrefix}.timedData.slides', const ['photo'], _entry.slides?.length ?? 0, _storedLengths[_millis]?['slides'] ?? 0, '.$_millis');
          _timedJson[_millis.toString()] = _values;
        }
        await HomeWidget.saveFile('${_$paramPrefix}.timedData', Uint8List.fromList(utf8.encode(jsonEncode(_timedJson))), extension: 'json', appGroupId: _$appGroupId);
        await _$deleteTimedListImages(_storedLengths, _storedLengths.keys.where((_millis) => !_timedJson.containsKey(_millis.toString())));
'''),
      );
      expect(
        output,
        contains(r'''
      if (timedData) () async {
        final _storedLengths = await _$storedTimedListLengths();
        await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
        await _$deleteTimedListImages(_storedLengths, _storedLengths.keys);
'''),
      );
      expect(
        output,
        contains(r'''
  static Future<Map<int, Map<String, int>>> _$storedTimedListLengths() async {
    final path = await HomeWidget.getWidgetData<String>('${_$paramPrefix}.timedData', appGroupId: _$appGroupId);
    if (path == null) return const {};
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (int.tryParse(key) case final millis?)
            millis: {
              if (value is Map<String, dynamic>)
                for (final list in const ['slides'])
                  if (value[list] case final List items) list: items.length,
            },
      };
    } on Exception {
      return const {};
    }
  }

  static Future<void> _$deleteTimedListImages(
    Map<int, Map<String, int>> stored,
    Iterable<int> times,
  ) async {
    await Future.wait([
      for (final millis in times)
        for (final MapEntry(key: list, value: fields) in const {'slides': ['photo']}.entries)
          _$deleteListImages('${_$paramPrefix}.timedData.$list', fields, 0, stored[millis]?[list] ?? 0, '.$millis'),
    ]);
  }

  static Future<void> _$deleteListImages(
    String key,
    List<String> fields,
    int from,
    int to, [
    String suffix = '',
  ]) async {
    await Future.wait([
      for (var index = from; index < to; index++)
        for (final field in fields)
          HomeWidget.saveWidgetData<String>('$key.$index.$field$suffix', null, appGroupId: _$appGroupId),
    ]);
  }
'''),
      );
      expect(output, isNot(contains(r'_$storedListLength')));
      expect(output, isNot(contains(r'_$storedTimedKeys')));
      expect(output, contains('  final ImageProvider? photo;\n'));
      expect(output, contains("      photo: _readFileImage(json['photo']),\n"));
    });

    test('prunes the item images of timed and untimed lists side by side', () {
      final output = DartHelperGenerator(
        _listSpec(
          const HWColumn(
            children: [
              HWImage(HWTimedData(HWImageData('backdrop'))),
              HWColumn.builder('contacts', maxItems: 3, item: _contactItem),
              HWColumn.builder('slides', maxItems: 3, item: _slideItem),
              HWColumn.builder(
                'badges',
                maxItems: 3,
                item: HWImage(HWTimedData(HWItemData(HWImageData('icon')))),
              ),
            ],
          ),
        ),
      ).generate();

      expect(
        output,
        contains(r'''
        final _storedTimes = await _$storedTimedKeys();
        final _storedLengths = await _$storedTimedListLengths();
        if (_timedTimes.isEmpty) {
          await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
          await _$deleteTimedImages(_storedTimes);
          await _$deleteTimedListImages(_storedLengths, _storedLengths.keys);
'''),
      );
      expect(
        output,
        contains(
          r"await _$deleteListImages('${_$paramPrefix}.contacts', "
          "const ['avatar', 'badge'], contacts.length, _storedLength);",
        ),
      );
      expect(
        output,
        contains(
          r"await _$deleteListImages('${_$paramPrefix}.timedData.badges', "
          "const ['icon'], _entry.badges?.length ?? 0, "
          r"_storedLengths[_millis]?['badges'] ?? 0, '.$_millis');",
        ),
      );
      expect(
        output,
        contains(
          r'''await _$deleteTimedImages(_storedTimes.where((_millis) => !_timedJson.containsKey(_millis.toString())));
        await _$deleteTimedListImages(_storedLengths, _storedLengths.keys.where((_millis) => !_timedJson.containsKey(_millis.toString())));''',
        ),
      );
      expect(
        output,
        contains(r'''
        final _storedTimes = await _$storedTimedKeys();
        final _storedLengths = await _$storedTimedListLengths();
        await HomeWidget.saveWidgetData('${_$paramPrefix}.timedData', null, appGroupId: _$appGroupId);
        await _$deleteTimedImages(_storedTimes);
        await _$deleteTimedListImages(_storedLengths, _storedLengths.keys);
'''),
      );
      expect(
        'static Future<int> _\$storedListLength('.allMatches(output),
        hasLength(1),
      );
      expect(
        output,
        contains("for (final list in const ['slides', 'badges'])"),
      );
      expect(
        output,
        contains("const {'slides': ['photo'], 'badges': ['icon']}.entries"),
      );
    });

    test('round-trips the item images of every timed entry through a PNG each',
        () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('slides', maxItems: 3, item: _slideItem),
          ),
        ).generate(),
        r'''
  String shown(Object? value) =>
      '$value'.replaceAll(HomeWidget.directory.path, '<dir>');
  final morning = DateTime.utc(2026, 9, 21, 6);
  final noon = DateTime.utc(2026, 9, 21, 12);
  await WeatherHomeWidget.saveData(
    timedData: {
      morning: WeatherTimedData(
        slides: [
          WeatherSlidesItem(caption: 'Sunrise', photo: MemoryImage(utf8.encode('sunrise'))),
          const WeatherSlidesItem(caption: 'Coffee'),
        ],
      ),
      noon: WeatherTimedData(
        slides: [
          WeatherSlidesItem(caption: 'Lunch', photo: MemoryImage(utf8.encode('lunch'))),
        ],
      ),
    },
  );
  print(shown(File(HomeWidget.data['home_widget.Weather.timedData'] as String).readAsStringSync()));
  print(HomeWidget.data.keys.toList()..sort());
  final timedData = (await WeatherHomeWidget.getData()).timedData!;
  for (final time in [morning, noon]) {
    for (final slide in timedData[time.toLocal()]!.slides!) {
      final photo = slide.photo;
      print([slide.caption, photo is FileImage ? photo.file.readAsStringSync() : photo]);
    }
  }
''',
      );

      final morning = DateTime.utc(2026, 9, 21, 6).millisecondsSinceEpoch;
      final noon = DateTime.utc(2026, 9, 21, 12).millisecondsSinceEpoch;
      expect(const LineSplitter().convert(output), [
        '{"$morning":{"slides":[{"caption":"Sunrise","photo":'
            '"<dir>/home_widget.Weather.timedData.slides.0.photo.$morning.png"},'
            '{"caption":"Coffee"}]},'
            '"$noon":{"slides":[{"caption":"Lunch","photo":'
            '"<dir>/home_widget.Weather.timedData.slides.0.photo.$noon.png"}]}}',
        '[home_widget.Weather.timedData, '
            'home_widget.Weather.timedData.slides.0.photo.$morning, '
            'home_widget.Weather.timedData.slides.0.photo.$noon]',
        '[Sunrise, sunrise]',
        '[Coffee, null]',
        '[Lunch, lunch]',
      ]);
    });

    test('deletes the timed item images a kept or dropped entry no longer has',
        () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('slides', maxItems: 3, item: _slideItem),
          ),
        ).generate(),
        r'''
  List<String> files() => [
        for (final file in HomeWidget.directory.listSync())
          file.path.split('/').last,
      ]..sort();
  WeatherSlidesItem slide(String name) =>
      WeatherSlidesItem(caption: name, photo: MemoryImage(utf8.encode(name)));
  final morning = DateTime.utc(2026, 9, 21, 6);
  final noon = DateTime.utc(2026, 9, 21, 12);
  final evening = DateTime.utc(2026, 9, 21, 18);
  await WeatherHomeWidget.saveData(
    timedData: {
      morning: WeatherTimedData(slides: [slide('a'), slide('b'), slide('c')]),
      noon: WeatherTimedData(slides: [slide('d'), slide('e')]),
      evening: WeatherTimedData(slides: [slide('f')]),
    },
  );
  print(files().length);
  await WeatherHomeWidget.saveData(
    timedData: {
      morning: WeatherTimedData(
        slides: [const WeatherSlidesItem(caption: 'a'), slide('b2')],
      ),
      evening: const WeatherTimedData(),
    },
  );
  print(files());
  print(HomeWidget.data.keys.toList()..sort());
  final slides = (await WeatherHomeWidget.getData()).timedData![morning.toLocal()]!.slides!;
  print([for (final item in slides) item.photo is FileImage ? (item.photo as FileImage).file.readAsStringSync() : item.photo]);
''',
      );

      final morning = DateTime.utc(2026, 9, 21, 6).millisecondsSinceEpoch;
      expect(const LineSplitter().convert(output), [
        '7',
        '[home_widget.Weather.timedData.json, '
            'home_widget.Weather.timedData.slides.1.photo.$morning.png]',
        '[home_widget.Weather.timedData, '
            'home_widget.Weather.timedData.slides.1.photo.$morning]',
        '[null, b2]',
      ]);
    });

    test('deletes every timed item image with the timeline', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('slides', maxItems: 3, item: _slideItem),
          ),
        ).generate(),
        r'''
  WeatherSlidesItem slide(String name) =>
      WeatherSlidesItem(caption: name, photo: MemoryImage(utf8.encode(name)));
  final morning = DateTime.utc(2026, 9, 21, 6);
  final noon = DateTime.utc(2026, 9, 21, 12);
  Future<void> save() => WeatherHomeWidget.saveData(
        timedData: {
          morning: WeatherTimedData(slides: [slide('a'), slide('b')]),
          noon: WeatherTimedData(slides: [slide('c')]),
        },
      );
  await save();
  await WeatherHomeWidget.saveData(timedData: const {});
  print(HomeWidget.directory.listSync());
  print(HomeWidget.data.keys.toList());
  print(HomeWidget.schedule);
  await save();
  await WeatherHomeWidget.deleteData(timedData: true);
  print(HomeWidget.directory.listSync());
  print(HomeWidget.data.keys.toList());
  print((await WeatherHomeWidget.getData()).timedData);
''',
      );

      expect(const LineSplitter().convert(output), [
        '[]',
        '[]',
        'null',
        '[]',
        '[]',
        'null',
      ]);
    });

    test('saves a timeline over a stored one it cannot read', () async {
      final output = await _runHelper(
        DartHelperGenerator(
          _listSpec(
            const HWColumn.builder('slides', maxItems: 3, item: _slideItem),
          ),
        ).generate(),
        r'''
  final file = File('${HomeWidget.directory.path}/stored.json');
  for (final content in [
    'not json',
    '[]',
    '{"soon": {}, "1000": 5, "2000": {"slides": 3}}',
  ]) {
    file.writeAsStringSync(content);
    HomeWidget.data['home_widget.Weather.timedData'] = file.path;
    await WeatherHomeWidget.saveData(
      timedData: {
        DateTime.utc(2026, 9, 21, 6): WeatherTimedData(
          slides: [WeatherSlidesItem(caption: 'Sunrise', photo: MemoryImage(utf8.encode('sunrise')))],
        ),
      },
    );
    final timedData = (await WeatherHomeWidget.getData()).timedData!;
    print(timedData.values.single.slides!.single.caption);
  }
''',
      );

      expect(const LineSplitter().convert(output), [
        'Sunrise',
        'Sunrise',
        'Sunrise',
      ]);
    });
  });
}

const _materialIcons = HWIconFont(family: 'MaterialIcons');

const _forecastCondition = HWIconData.resolved(
  'condition',
  entries: [HWIconEntry('wbSunny', 0xe2bd), HWIconEntry('cloud', 0xe2bf)],
  iconFont: _materialIcons,
  defaultValue: 0xe2bd,
);

/// The item of a forecast list, reading one field of every kind.
const _forecastItem = HWColumn(
  children: [
    HWText.dateTime(HWItemData(HWDateTime('day'))),
    HWIcon(HWItemData(_forecastCondition)),
    HWText.number(HWItemData(HWInt('temperature', defaultValue: 0))),
    HWText.number(HWItemData(HWDouble('rain'))),
    HWBoolConditional(
      data: HWItemData(HWBool('windy', defaultValue: false)),
      whenTrue: HWText.fixed('windy'),
      whenFalse: HWText.fixed('calm'),
    ),
    HWText(HWItemData(HWString('note'))),
  ],
);

/// The item of a contacts list, holding two images beside its name.
const _contactItem = HWRow(
  children: [
    HWImage(HWItemData(HWImageData('avatar'))),
    HWText(HWItemData(HWString('name'))),
    HWImage(HWItemData(HWImageData('badge'))),
  ],
);

/// The item of a time-based hourly list.
const _hourlyItem = HWRow(
  children: [
    HWText.dateTime(HWTimedData(HWItemData(HWDateTime('time')))),
    HWText.number(
      HWTimedData(HWItemData(HWInt('temperature', defaultValue: 0))),
    ),
    HWText(HWTimedData(HWItemData(HWString('note')))),
  ],
);

/// The item of a time-based slides list, holding an image beside its caption.
const _slideItem = HWRow(
  children: [
    HWImage(HWTimedData(HWItemData(HWImageData('photo')))),
    HWText(HWTimedData(HWItemData(HWString('caption')))),
  ],
);

/// An iOS widget `Weather` rendering [tree], which is where its lists come
/// from.
WidgetSpec _listSpec(HWWidget tree) => WidgetSpec(
      data: HomeWidget(
        name: 'Weather',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.weather'),
      ),
      className: 'Weather',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

const _mood = HWIconData.resolved(
  'mood',
  entries: [HWIconEntry('wbSunny', 0xe2bd), HWIconEntry('cloud', 0xe2bf)],
  iconFont: _materialIcons,
  defaultValue: 0xe2bd,
);

const _condition = HWIconData.resolved(
  'condition',
  entries: [HWIconEntry('cloud', 0xe2bf)],
  iconFont: _materialIcons,
  defaultValue: 0xe2bf,
);

const _slot = HWIconData.resolved(
  'slot',
  entries: [HWIconEntry('star', 0xe838)],
  iconFont: _materialIcons,
);

/// Runs part of a generated helper in a subprocess, so an encode/decode test
/// asserts behavior rather than source text.
///
/// The extract starts at [firstClass] and runs to the end of the file, which is
/// where the generated data classes and their readers live — none of them
/// touches `package:home_widget`, so it runs with no package config.
Future<String> _runGenerated(
  String dart,
  String firstClass,
  String body,
) async {
  final start = dart.indexOf(firstClass);
  expect(start, isNonNegative, reason: '$firstClass was not emitted');

  final dir = await Directory.systemTemp.createTemp('hw_datetime_run_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final file = File(p.join(dir.path, 'main.dart'));
  await file.writeAsString('${dart.substring(start)}\nvoid main() {\n$body}\n');

  final result = await Process.run(Platform.resolvedExecutable, [file.path]);
  if (result.exitCode != 0) {
    fail('generated code did not run:\n${result.stdout}\n${result.stderr}');
  }
  return (result.stdout as String).trim();
}

/// Runs a whole generated helper in a subprocess, against [_pluginStub] in
/// place of `package:home_widget` and the Flutter types it names, so a test
/// saves and reads back through the generated API itself.
///
/// [body] runs with `HomeWidget.directory`, where the stub writes files, set
/// to a fresh directory.
Future<String> _runHelper(String dart, String body) async {
  final dir = await Directory.systemTemp.createTemp('hw_helper_run_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final storage = Directory(p.join(dir.path, 'storage'))..createSync();
  final generated =
      dart.replaceAll(RegExp(r"^import '.*';$", multiLine: true), '');
  final file = File(p.join(dir.path, 'main.dart'));
  await file.writeAsString('''
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

$generated
$_pluginStub
Future<void> main() async {
  HomeWidget.directory = Directory(r'${storage.path}');
$body}
''');

  final result = await Process.run(Platform.resolvedExecutable, [file.path]);
  if (result.exitCode != 0) {
    fail('generated code did not run:\n${result.stdout}\n${result.stderr}');
  }
  return (result.stdout as String).trim();
}

/// What a generated helper of an iOS-only widget calls on the plugin, backed
/// by a map for the preferences and by real files for `saveFile`, and the
/// Flutter error reporting a timed save guards its scheduling with.
///
/// Clearing a key holding a file's path deletes the file if it is still
/// there, as the plugin does.
/// `saveImage` writes the bytes an image carries rather than encoding a PNG.
/// The update times last scheduled are kept in `HomeWidget.schedule`.
const _pluginStub = r'''
class ErrorDescription {
  const ErrorDescription(this.message);

  final String message;
}

class FlutterErrorDetails {
  const FlutterErrorDetails({
    required this.exception,
    this.stack,
    this.library,
    this.context,
  });

  final Object exception;
  final StackTrace? stack;
  final String? library;
  final ErrorDescription? context;
}

class FlutterError {
  static void reportError(FlutterErrorDetails details) {}
}

sealed class ImageProvider {
  const ImageProvider();
}

class MemoryImage extends ImageProvider {
  const MemoryImage(this.bytes);

  final List<int> bytes;
}

class FileImage extends ImageProvider {
  const FileImage(this.file);

  final File file;

  /// The real one drops the decoded bitmap of [file] from Flutter's image
  /// cache; there is no cache here, so nothing was ever cached.
  Future<bool> evict() async => false;
}

class IconData {
  const IconData(
    this.codePoint, {
    this.fontFamily,
    this.fontPackage,
    this.matchTextDirection = false,
  });

  final int codePoint;
  final String? fontFamily;
  final String? fontPackage;
  final bool matchTextDirection;
}

class HomeWidgetInfo {
  const HomeWidgetInfo({this.androidClassName, this.iOSKind});

  final String? androidClassName;
  final String? iOSKind;
}

class HomeWidget {
  static final data = <String, Object?>{};
  static late Directory directory;
  static List<DateTime>? schedule;

  static Future<bool?> saveWidgetData<T>(
    String id,
    T? value, {
    String? appGroupId,
  }) async {
    if (value != null) {
      data[id] = value;
      return true;
    }
    final stored = data.remove(id);
    if (stored is String && stored.startsWith(directory.path)) {
      final file = File(stored);
      if (file.existsSync()) file.deleteSync();
    }
    return true;
  }

  static Future<T?> getWidgetData<T>(
    String id, {
    T? defaultValue,
    String? appGroupId,
  }) async =>
      data[id] as T? ?? defaultValue;

  static Future<String> saveFile(
    String key,
    Uint8List bytes, {
    String extension = 'bin',
    String? appGroupId,
  }) async {
    final file = File('${directory.path}/$key.$extension');
    await file.writeAsBytes(bytes);
    data[key] = file.path;
    return file.path;
  }

  static Future<String> saveImage(
    String key,
    ImageProvider imageProvider, {
    String? appGroupId,
  }) {
    final bytes = switch (imageProvider) {
      MemoryImage(:final bytes) => bytes,
      FileImage(:final file) => file.readAsBytesSync(),
    };
    return saveFile(
      key,
      Uint8List.fromList(bytes),
      extension: 'png',
      appGroupId: appGroupId,
    );
  }

  static Future<bool?> updateWidget({
    String? androidName,
    String? iOSName,
    String? qualifiedAndroidName,
  }) async =>
      true;

  static Future<bool?> scheduleWidgetUpdates(
    List<DateTime> updateTimes, {
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) async {
    schedule = updateTimes;
    return true;
  }

  static Future<bool?> cancelScheduledWidgetUpdates({
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) async {
    schedule = null;
    return true;
  }

  static Future<List<HomeWidgetInfo>> getInstalledWidgets() async => const [];
}
''';
