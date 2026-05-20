import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

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
    expect(content, contains('.applyContainerBackground()'));
    expect(content, contains('func applyContainerBackground() -> some View'));
    expect(content, isNot(contains('func applyContainerBackground<T: View>')));
    expect(
      content,
      contains('containerBackground(.fill.tertiary, for: .widget)'),
    );
  });

  test('generates Swift widget with JSON data structs', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'JsonWidget',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.com.example',
        ),
      ),
      className: 'JsonWidget',
      dataFields: const [
        HWJson('fileKey', HWString('title')),
        HWJson('fileKey', HWBool('enabled', defaultValue: false)),
      ],
      widgetTree: const HWBoolConditional(
        data: HWJson('fileKey', HWBool('enabled', defaultValue: false)),
        whenTrue: HWText.fixed('Enabled'),
        whenFalse: HWText.fixed('Disabled'),
      ),
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/JsonWidgetHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(content, contains('let fileKey: JsonWidgetFileKeyJsonData?'));
    expect(
      content,
      contains(
        'fileKey: JsonWidgetFileKeyJsonData.fromPath(defaults?.string(forKey: "\\(paramPrefix).fileKey")),',
      ),
    );
    expect(content, contains('struct JsonWidgetFileKeyJsonData {'));
    expect(content, contains('let enabled: Bool = false'));
    expect(
      content,
      contains(
        'if (((entry.data.fileKey?.enabled) ?? (false))) == true {',
      ),
    );
  });

  test('generates Swift widget with nested JSON lookups from root file',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NestedJsonWidget',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.com.example',
        ),
      ),
      className: 'NestedJsonWidget',
      dataFields: const [
        HWJson(
          'fileKey',
          HWJson('user', HWBool('enabled', defaultValue: true)),
        ),
      ],
      widgetTree: const HWBoolConditional(
        data: HWJson(
          'fileKey',
          HWJson('user', HWBool('enabled', defaultValue: true)),
        ),
        whenTrue: HWText.fixed('Enabled'),
        whenFalse: HWText.fixed('Disabled'),
      ),
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/NestedJsonWidgetHomeWidget/Widget.swift',
      ),
    );
    final content = widgetFile.readAsStringSync();

    expect(content, contains('let user: NestedJsonWidgetFileKeyJsonDataUser?'));
    expect(
      content,
      contains('defaults?.string(forKey: "\\(paramPrefix).fileKey")'),
    );
    expect(
      content,
      contains(
        'NestedJsonWidgetFileKeyJsonDataUser.fromJson(values["user"] as? [String: Any])',
      ),
    );
    expect(content, contains('let values = json ?? [:]'));
    expect(content, contains('enabled: (values["enabled"] as? Bool) ?? true,'));
    expect(content, contains('let enabled: Bool = true'));
    expect(
      content,
      contains(
        'if (((entry.data.fileKey?.user?.enabled) ?? (true))) == true {',
      ),
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
  });

  test(
      'generates Swift widget with contentMarginsDisabled when applyContentPadding is false',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NoPaddingWidget',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.nopadding',
          applyContentPadding: false,
        ),
      ),
      className: 'NoPaddingWidget',
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/NoPaddingWidgetHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(content, contains('.disableContentMarginsIfNeeded()'));
    expect(
      content,
      contains(
        'func disableContentMarginsIfNeeded() -> some WidgetConfiguration {',
      ),
    );
    expect(content, contains('self.contentMarginsDisabled()'));
  });

  test('generates Swift widget with HWPadding', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'PaddingWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.padding'),
      ),
      className: 'PaddingWidget',
      widgetTree: HWPadding(
        padding: HWEdgeInsets.all(16),
        child: HWText(HWString('title')),
      ),
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'ios/PaddingWidgetHomeWidget/Widget.swift',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(
      content,
      contains(
        '.padding(EdgeInsets(top: 16.0, leading: 16.0, bottom: 16.0, trailing: 16.0))',
      ),
    );
  });

  test('warns and skips wiring when ios/ is missing', () async {
    final saved = logger;
    final mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.warn(any())).thenReturn(null);
    addTearDown(() => logger = saved);

    final root = Directory.systemTemp.createTempSync('ios_gen_no_ios');
    addTearDown(() => root.deleteSync(recursive: true));

    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'X',
        iOS: HomeWidgetIOSConfiguration(groupId: 'g'),
      ),
      className: 'X',
    );

    await IosGenerator(spec: spec, projectRoot: root).generate();

    verify(
      () => mockLogger.warn(any(that: contains('ios/ not found'))),
    ).called(1);
  });

  test('applies custom background and disables content padding', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'BgPad',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.bg',
          backgroundColor: HWFixedColor(0xFFE91E63),
          applyContentPadding: false,
        ),
      ),
      className: 'BgPadWidget',
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final content = File(
      p.join(tempDir.path, 'ios/BgPadWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, contains('.applyContainerBackground(Color('));
    expect(content, contains('func applyContainerBackground<T: View>'));
    expect(
      content,
      isNot(contains('func applyContainerBackground() -> some View')),
    );
    expect(content, contains('disableContentMarginsIfNeeded'));
  });

  test('escapes embedded quotes in Swift string defaults for JSON fields',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'QuoteJson',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.q'),
      ),
      className: 'QuoteJson',
      dataFields: const [
        HWJson('jf', HWString('caption', defaultValue: 'Say "hello"')),
      ],
      widgetTree: const HWText(
        HWJson('jf', HWString('caption', defaultValue: 'Say "hello"')),
      ),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/QuoteJsonHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, contains(r'caption: String = "Say \"hello\""'));
  });
}
