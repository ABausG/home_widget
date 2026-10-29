import 'dart:io';

import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/parser/schema_parser.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Schema Parser Layout Tests', () {
    late Directory tempDir;

    setUp(() async {
      final currentTestDir = Directory.current.path;
      final testDir =
          Directory(p.join(currentTestDir, 'test', '.tmp_layout_test'));
      if (!await testDir.exists()) {
        await testDir.create(recursive: true);
      }
      tempDir = await testDir.createTemp('layout_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<WidgetSpec?> parseSourceInTempFile(String source) async {
      final file = File(p.join(tempDir.path, 'test.dart'));
      await file.writeAsString(source);

      // We need to ensure the package imports are resolvable or mocked if necessary.
      // For this integration test, we assume the environment can handle it or we use
      // a relative path if needed, but the parser likely just reads the string content
      // and resolves based on that.

      final specs = await parseSchemaFile(file.path);
      if (specs.isEmpty) return null;
      return specs.first;
    }

    test('parses nested HWColumn and HWRow with children', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Complex Layout',
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.example',
          ),
          widget: HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
            children: [
              HWText.fixed('Hello World'),
              HWRow(
                mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
                children: [HWText.fixed('1'), HWText.fixed('2')],
              ),
            ],
          ),
        )
        class ComplexLayout {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec, isNotNull);
      final widgetTree = spec!.widgetTree;
      expect(widgetTree, isA<HWColumn>());
      final column = widgetTree as HWColumn;

      expect(column.children, hasLength(2));

      expect(column.children[0], isA<HWText>());
      expect((column.children[0] as HWText).fixedContent, 'Hello World');

      expect(column.children[1], isA<HWRow>());
      final row = column.children[1] as HWRow;
      expect(row.children, hasLength(2));
    });

    test('parses a builder into a list of its own', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Weather',
          android: HomeWidgetAndroidConfiguration(),
          widget: HWColumn(
            children: [
              HWText(HWString('city')),
              HWRow.builder(
                'forecast',
                maxItems: 5,
                mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
                item: HWColumn(
                  children: [
                    HWText.dateTime(
                      HWItemData(
                        HWDateTime('day'),
                        previewValues: [
                          '2026-09-21T12:00:00Z',
                          '2026-09-22T12:00:00Z',
                        ],
                      ),
                      format: HWDateFormat.skeleton('E'),
                    ),
                    HWText.number(
                      HWItemData(
                        HWInt('temperature', defaultValue: 0),
                        previewValues: [21, 17],
                      ),
                    ),
                    HWText(HWString('unit', defaultValue: 'C')),
                  ],
                ),
                whenEmpty: HWText.fixed('No forecast yet'),
              ),
            ],
          ),
        )
        class Weather {}
      ''';

      final spec = await parseSourceInTempFile(source);
      expect(spec!.dataFields.map((f) => f.key), ['city', 'unit']);

      final group = spec.listDataGroups.single;
      expect(group.itemClassName(spec.className), 'WeatherForecastItem');
      expect(group.fields.map((f) => f.key), ['day', 'temperature']);
      expect(group.sampleItemCount, 2);
      expect(group.sampleValue(group.fields.last, 1), 17);
    });

    test('rejects an item field read outside a builder', () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Stray',
          widget: HWText(HWItemData(HWString('label'))),
        )
        class Stray {}
      ''';

      await expectLater(
        parseSourceInTempFile(source),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('reads the item a builder is rendering'),
          ),
        ),
      );
    });

    test('rejects an item bool without a default in HWBoolConditional',
        () async {
      const source = '''
        import 'package:home_widget_generator/home_widget_generator.dart';

        @HomeWidget(
          name: 'Tasks',
          widget: HWColumn.builder(
            'tasks',
            item: HWBoolConditional(
              data: HWItemData(HWBool('done')),
              whenTrue: HWText.fixed('done'),
              whenFalse: HWText.fixed('open'),
            ),
          ),
        )
        class Tasks {}
      ''';

      await expectLater(
        parseSourceInTempFile(source),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('non-null defaultValue'),
          ),
        ),
      );
    });
  });
}
