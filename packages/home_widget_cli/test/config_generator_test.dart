import 'package:home_widget_cli/src/generators/config_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigGenerator', () {
    test('generates config with data fields', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: [
          DataFieldSpec(key: 'countLabel', type: HWDataFieldType.string),
          DataFieldSpec(key: 'count', type: HWDataFieldType.int_),
        ],
      );

      final generator = ConfigGenerator(spec);
      final output = generator.generate();

      expect(output, contains('class ExampleWidgetData {'));
      expect(output, contains('const ExampleWidgetData._();'));
      expect(
        output,
        contains(
          "HWDataRef<String> get countLabel => const HWDataRef<String>('countLabel');",
        ),
      );
      expect(
        output,
        contains("HWDataRef<int> get count => const HWDataRef<int>('count');"),
      );
      expect(
        output,
        contains('const exampleWidgetData = ExampleWidgetData._();'),
      );
    });

    test('generates config with empty data fields', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'ExampleWidget'),
        className: 'ExampleWidget',
        dataFields: [],
      );

      final generator = ConfigGenerator(spec);
      final output = generator.generate();

      expect(output, contains('class ExampleWidgetData {'));
      expect(
        output,
        isNot(contains('HWDataRef')),
      );
    });
  });
}
