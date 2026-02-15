import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:home_widget_cli/src/models/widget_node.dart'; // NEW
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ios_gen_test');
    Directory(p.join(tempDir.path, 'ios')).createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('generates Swift widget with data struct', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'ExampleWidget',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.com.example',
        ),
      ),
      className: 'ExampleWidget',
      dataFields: [
        DataFieldSpec(key: 'count', type: HWDataFieldType.int_),
        DataFieldSpec(key: 'label', type: HWDataFieldType.string),
      ],
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/ExampleWidgetHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    // Check Data Struct
    expect(content, contains('struct ExampleWidgetData {'));
    expect(content, contains('let count: Int?'));
    expect(content, contains('let label: String?'));
    expect(
      content,
      contains(
        'static func fromUserDefaults(_ defaults: UserDefaults?) -> ExampleWidgetData',
      ),
    );
    expect(
      content,
      contains('defaults?.object(forKey: "\\(paramPrefix).count") as? Int'),
    );
    expect(
      content,
      contains('defaults?.string(forKey: "\\(paramPrefix).label")'),
    );

    // Check Entry
    expect(
      content,
      contains('struct ExampleWidgetHomeWidgetEntry: TimelineEntry {'),
    );
    expect(content, contains('let data: ExampleWidgetData'));

    // Check Provider
    expect(
      content,
      contains('let prefs = UserDefaults(suiteName: "group.com.example")'),
    );
    expect(
      content,
      contains('let data = ExampleWidgetData.fromUserDefaults(prefs)'),
    );
    expect(
      content,
      contains('ExampleWidgetHomeWidgetEntry(date: Date(), data: data)'),
    );

    // Check View
    expect(
      content,
      contains('Text("count: \\(entry.data.count?.description ?? "-")")'),
    );
    expect(
      content,
      contains('Text("count: \\(entry.data.count?.description ?? "-")")'),
    );
  });

  test('generates Swift widget with v2 metadata and families', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'V2Widget',
        description: 'A v2 widget description',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.v2',
          supportedFamilies: [
            HWWidgetFamily.systemSmall,
            HWWidgetFamily.systemMedium,
          ],
        ),
      ),
      className: 'V2Widget',
      dataFields: [],
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/V2WidgetHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(content, contains('.configurationDisplayName("V2Widget")'));
    expect(content, contains('.description("A v2 widget description")'));
    expect(
      content,
      contains('.supportedFamilies([.systemSmall, .systemMedium])'),
    );
  });

  test('generates Swift widget with widget tree', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TreeWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.tree'),
      ),
      className: 'TreeWidget',
      dataFields: [
        DataFieldSpec(key: 'title', type: HWDataFieldType.string),
      ],
      widgetTree: TextNode(
        content: DataRefValue(key: 'title', type: HWDataFieldType.string),
      ),
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/TreeWidgetHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    // Should use the emitter output
    expect(content, contains('Text(entry.data.title ?? "")'));
    // Should NOT contain placeholder VStack
    expect(content, isNot(contains('VStack {')));
  });
}
