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
          DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
          DataFieldSpec(key: 'count', type: HWDataFieldType.int_),
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
          "if (countLabel != null) HomeWidget.saveWidgetData<String>('countLabel', countLabel),",
        ),
      );
      expect(
        output,
        contains(
          "if (count != null) HomeWidget.saveWidgetData<int>('count', count),",
        ),
      );

      // deleteData
      expect(output, contains('static Future<void> deleteData({'));
      expect(output, contains('bool countLabel = false,'));
      expect(output, contains('bool count = false,'));
      expect(
        output,
        contains(
          "if (countLabel) HomeWidget.saveWidgetData('countLabel', null),",
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
          "countLabel: await HomeWidget.getWidgetData<String>('countLabel'),",
        ),
      );
      expect(
        output,
        contains("count: await HomeWidget.getWidgetData<int>('count'),"),
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

    test('generates ensureInitialized method', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'ExampleWidget',
        interactivity: InteractivitySpec(
          import: 'package:example/main.dart',
          callback: 'callback',
        ),
      );

      final generator = DartHelperGenerator(spec);
      final output = generator.generate();

      expect(output, contains("import 'package:example/main.dart';"));
      expect(
        output,
        contains('static Future<void> ensureInitialized() async {'),
      );
      expect(
        output,
        contains("await HomeWidget.setAppGroupId('group.example');"),
      );
      expect(
        output,
        contains(
          "await HomeWidget.registerInteractivityCallback(callback);",
        ),
      );
    });
  });
}
