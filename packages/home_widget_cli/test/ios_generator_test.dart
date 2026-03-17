import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
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
        HWInt('count'),
        HWString('label'),
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

    // Check View — default tree uses separate Text views in HStack
    expect(content, contains('Text("count: ")'));
    expect(
      content,
      contains('Text(entry.data.count != nil ? "\\(entry.data.count!)" : "0")'),
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
        HWString('title'),
      ],
      widgetTree: HWText(
        HWString('title'),
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
    expect(content, contains('.applyContainerBackground()'));
    expect(content, isNot(contains('Color.clear')));
  });

  test('generates Swift widget with HWDataOnly as root widget', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'Simple Data',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
      ),
      className: 'SimpleData',
      dataFields: [
        HWString('label'),
        HWInt('value'),
      ],
      widgetTree: HWDataOnly([
        HWString('label'),
        HWInt('value'),
      ]),
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/SimpleDataHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    // Should contain data struct
    expect(content, contains('struct SimpleDataData {'));
    expect(content, contains('let label: String?'));
    expect(content, contains('let value: Int?'));

    // Should produce the debug VStack view body
    expect(content, contains('VStack {'));
    expect(content, contains('Text("Simple Data")'));
    // Default tree uses separate Text views in HStack
    expect(content, contains('Text("label: ")'));
    expect(
      content,
      contains('Text(entry.data.label ?? "")'),
    );
    expect(content, contains('Text("value: ")'));
    expect(
      content,
      contains('Text(entry.data.value != nil ? "\\(entry.data.value!)" : "0")'),
    );
    expect(content, contains('.applyContainerBackground()'));
  });
}
