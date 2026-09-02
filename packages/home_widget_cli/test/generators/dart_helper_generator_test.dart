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
          "if (avatar != null) HomeWidget.saveImage('\${_\$paramPrefix}.avatar', avatar),",
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
          "HomeWidget.saveImage('\${_\$paramPrefix}.avatar', avatar, appGroupId: _\$appGroupId)",
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
          "_contactJson['avatar'] = await HomeWidget.saveImage("
          "'\${_\$paramPrefix}.contact.avatar', _jsonImage_contact_avatar, "
          'appGroupId: _\$appGroupId);',
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
          'final _jsonImage_contact_photos_main = contact.photos?.main;',
        ),
      );
      expect(
        output,
        contains(
          "(_contactJson['photos']! as Map<String, dynamic>)['main'] = "
          "await HomeWidget.saveImage('"
          "\${_\$paramPrefix}.contact.photos.main', _jsonImage_contact_photos_main, "
          'appGroupId: _\$appGroupId);',
        ),
      );
      // Images are written before the blob that has to carry their paths.
      expect(
        output.indexOf('HomeWidget.saveImage('),
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
        contains('final _jsonImage_slot_picture = _entry.slot?.picture;'),
      );
      expect(
        output,
        contains(
          "(_values['slot']! as Map<String, dynamic>)['picture'] = "
          "await HomeWidget.saveImage('"
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
        contains('final _timedImage_contactAvatar = _entry.contactAvatar;'),
      );
      expect(
        output,
        contains(
          'final _jsonImage_contact_avatar = _entry.contact?.avatar;',
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
        contains('final _jsonImage_media_photoSet = media.photoSet;'),
      );
      expect(
        output,
        contains('final _jsonImage_media_photo_set = media.photo?.set;'),
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
      final saveImageAt = output.indexOf('HomeWidget.saveImage(');
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
          "_values['slide'] = await HomeWidget.saveImage("
          "'\${_\$paramPrefix}.timedData.slide.\$_millis', _timedImage_slide, "
          'appGroupId: _\$appGroupId);',
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

    test('emits the launch helpers when a widget URL is configured', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'LinkedWidget', widgetUrl: 'myapp://linked'),
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
        data: HomeWidget(name: 'LinkedWidget', widgetUrl: 'myApp://linked'),
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
        data: HomeWidget(name: 'LinkedWidget', widgetUrl: 'myapp://linked'),
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
  });
}
