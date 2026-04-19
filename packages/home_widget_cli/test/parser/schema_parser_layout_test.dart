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
  });
}
