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

  test('generates Swift widget with image data fields', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'ImageWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.image'),
      ),
      className: 'ImageWidget',
      dataFields: const [
        HWImageData('avatar'),
        HWImageData.asset('assets/logo.png'),
      ],
      widgetTree: const HWColumn(
        children: [
          HWImage(HWImageData('avatar'), width: 100, height: 100),
          HWImage.asset('assets/logo.png', fit: HWImageFit.cover),
        ],
      ),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/ImageWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // Runtime image paths are plain nullable strings in the Data struct;
    // asset images are never stored.
    expect(content, contains('struct ImageWidgetData {'));
    expect(content, contains('let avatar: String?'));
    expect(content, isNot(contains('assetsLogoPng')));
    expect(
      content,
      contains('avatar: defaults?.string(forKey: "\\(paramPrefix).avatar"),'),
    );

    // View body renders the runtime image from disk and the asset from the
    // containing app bundle.
    expect(
      content,
      contains(
        'if let path = entry.data.avatar, let uiImage = UIImage(contentsOfFile: path) {',
      ),
    );
    expect(content, contains('Image(uiImage: uiImage)'));
    expect(content, contains('.frame(width: 100.0, height: 100.0)'));
    expect(
      content,
      contains(
        'if let path = flutterAssetPath("assets/logo.png"), '
        'let uiImage = UIImage(contentsOfFile: path) {',
      ),
    );
    expect(content, contains('.aspectRatio(contentMode: .fill)'));

    // The bundle-reading helper is emitted once for the whole file.
    expect(
      content,
      contains('private func flutterAssetPath(_ asset: String) -> String? {'),
    );
    expect(
      content,
      contains(
        '.appendingPathComponent("Frameworks/App.framework/flutter_assets")',
      ),
    );
    expect(
      'private func flutterAssetPath'.allMatches(content).length,
      1,
    );
  });

  test('emits the asset helper only when an asset image is present', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'RuntimeOnly',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.image'),
      ),
      className: 'RuntimeOnly',
      dataFields: const [HWImageData('avatar')],
      widgetTree: const HWImage(HWImageData('avatar')),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/RuntimeOnlyHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, isNot(contains('flutterAssetPath')));
  });

  test('reads a timed image path out of the active entry', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TimedImage',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.image'),
      ),
      className: 'TimedImage',
      dataFields: const [HWTimedData(HWImageData('slide'))],
      widgetTree: const HWImage(HWTimedData(HWImageData('slide'))),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/TimedImageHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // The resolved value is a path string, read like any other timed value...
    expect(content, contains('let slide: String?'));
    expect(content, contains('slide: timedValues["slide"] as? String,'));
    // ...and rendered exactly like an untimed runtime image.
    expect(
      content,
      contains(
        'if let path = entry.data.slide, '
        'let uiImage = UIImage(contentsOfFile: path) {',
      ),
    );
    // The image's timestamps drive the WidgetKit timeline like any timed field.
    expect(
      content,
      contains('for timedEntry in timedEntries where timedEntry.date > now {'),
    );
    expect(content, isNot(contains('flutterAssetPath')));
  });

  test('reads an image leaf of a JSON group as a path', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'JsonImage',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.image'),
      ),
      className: 'JsonImage',
      dataFields: const [HWJson('contact', HWImageData('avatar'))],
      widgetTree: const HWImage(HWJson('contact', HWImageData('avatar'))),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/JsonImageHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, contains('let avatar: String?'));
    expect(
      content,
      contains('avatar: (values["avatar"] as? String) ?? nil,'),
    );
    expect(
      content,
      contains(
        'if let path = entry.data.contact?.avatar, '
        'let uiImage = UIImage(contentsOfFile: path) {',
      ),
    );
    expect(content, isNot(contains('flutterAssetPath')));
  });

  test('prefixes a package asset with packages/<package>', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'PackageAsset',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.image'),
      ),
      className: 'PackageAsset',
      dataFields: const [
        HWImageData.asset('assets/logo.png', package: 'my_icons'),
      ],
      widgetTree: const HWImage.asset('assets/logo.png', package: 'my_icons'),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/PackageAssetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(
      content,
      contains('flutterAssetPath("packages/my_icons/assets/logo.png")'),
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
    expect(content, contains('let enabled: Bool\n'));
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
    // Non-optional, but without an initializer: a `let` with one is left out
    // of the memberwise init that `fromJson` calls, which is where the default
    // is applied.
    expect(content, contains('let enabled: Bool\n'));
    expect(content, isNot(contains('let enabled: Bool = true')));
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

  test('generates Swift widget with timed primitive data', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TimedWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
      ),
      className: 'TimedWidget',
      dataFields: const [
        HWString('title'),
        HWTimedData(HWString('label')),
        HWTimedData(HWInt('temperature', defaultValue: 7)),
      ],
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/TimedWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // Timed fields become regular properties of the data struct.
    expect(content, contains('let label: String?'));
    expect(content, contains('let temperature: Int?'));

    // fromUserDefaults resolves at a point in time.
    expect(content, contains('static func fromUserDefaults('));
    expect(content, contains('    at date: Date = Date(),'));
    expect(
      content,
      contains(
        '    timedEntries: [(date: Date, values: [String: Any])]? = nil',
      ),
    );
    expect(
      content,
      contains(
        'let timedValues = activeTimedValues(timedEntries ?? loadTimedEntries(defaults), at: date)',
      ),
    );
    expect(content, contains('label: timedValues["label"] as? String,'));
    expect(
      content,
      contains('temperature: (timedValues["temperature"] as? Int) ?? 7,'),
    );

    // Loader reads the file path from the timedData preference key.
    expect(
      content,
      contains(
        'fileprivate static func loadTimedEntries(_ defaults: UserDefaults?) -> [(date: Date, values: [String: Any])] {',
      ),
    );
    expect(
      content,
      contains(
        'guard let path = defaults?.string(forKey: "\\(paramPrefix).timedData") else { return [] }',
      ),
    );
    expect(
      content,
      contains(
        'entries.append((date: Date(timeIntervalSince1970: millis / 1000), values: values))',
      ),
    );

    // Resolver picks the greatest timestamp <= the resolution date.
    expect(
      content,
      contains(
        'fileprivate static func activeTimedValues(_ entries: [(date: Date, values: [String: Any])], at date: Date) -> [String: Any] {',
      ),
    );
    expect(content, contains('if entry.date > date { break }'));

    // getTimeline loads once and emits one entry per future timestamp.
    expect(
      content,
      contains('let timedEntries = TimedWidgetData.loadTimedEntries(prefs)'),
    );
    expect(
      content,
      contains(
        'data: TimedWidgetData.fromUserDefaults(prefs, at: now, timedEntries: timedEntries)',
      ),
    );
    expect(
      content,
      contains('for timedEntry in timedEntries where timedEntry.date > now {'),
    );
    expect(
      content,
      contains(
        'data: TimedWidgetData.fromUserDefaults(prefs, at: timedEntry.date, timedEntries: timedEntries)',
      ),
    );
    expect(
      content,
      contains('completion(Timeline(entries: entries, policy: .atEnd))'),
    );

    // placeholder/getSnapshot keep resolving at "now" with the default args.
    expect(
      content,
      contains(
        'TimedWidgetHomeWidgetEntry(date: Date(), data: TimedWidgetData.fromUserDefaults(nil))',
      ),
    );
    expect(
      content,
      contains('let data = TimedWidgetData.fromUserDefaults(prefs)'),
    );
  });

  test('generates Swift widget with timed JSON data structs', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TimedJsonWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
      ),
      className: 'TimedJsonWidget',
      dataFields: const [
        HWTimedData(HWJson('weather', HWString('condition'))),
        HWTimedData(HWJson('weather', HWJson('wind', HWInt('speed')))),
      ],
      widgetTree: const HWText(
        HWTimedData(HWJson('weather', HWString('condition'))),
      ),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/TimedJsonWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, contains('let weather: TimedJsonWidgetWeatherJsonData?'));
    expect(
      content,
      contains(
        'weather: TimedJsonWidgetWeatherJsonData.fromJson(timedValues["weather"] as? [String: Any]),',
      ),
    );
    // Nested structs are emitted even though timed groups are absent from
    // jsonDataGroups.
    expect(content, contains('struct TimedJsonWidgetWeatherJsonData {'));
    expect(
      content,
      contains('struct TimedJsonWidgetWeatherJsonDataWind {'),
    );
    expect(
      content,
      contains(
        'wind: TimedJsonWidgetWeatherJsonDataWind.fromJson(values["wind"] as? [String: Any]),',
      ),
    );
    expect(content, contains('Text(entry.data.weather?.condition ?? "")'));
  });

  test('re-reads the entry view at the entry date once timed fields exist',
      () async {
    const greeting = HWLocalizedString(
      'greeting',
      defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
    );
    const tree = HWColumn(
      children: [
        HWText(greeting),
        HWText(HWTimedData(HWInt('temperature'))),
      ],
    );
    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'Mixed',
        widget: tree,
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
        localization: HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'Mixed',
      dataFields: const [greeting, HWTimedData(HWInt('temperature'))],
      widgetTree: tree,
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/MixedHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // Re-reading at `Date()` would pin every entry of the timeline to the
    // values that were active when WidgetKit asked for it.
    expect(
      content,
      contains(
        'let data = MixedData.fromUserDefaults(prefs, at: entry.date, '
        'timedEntries: entry.timedEntries)',
      ),
    );
    // The entry carries the already-parsed timed data so the view does not
    // re-read and re-parse the file on every timeline entry.
    expect(
      content,
      contains(
        'struct MixedHomeWidgetEntry: TimelineEntry {\n'
        '  let date: Date\n'
        '  let data: MixedData\n'
        '  let timedEntries: [(date: Date, values: [String: Any])]\n'
        '}',
      ),
    );
    expect(
      content,
      contains(
        'MixedHomeWidgetEntry(date: Date(), data: MixedData.fromUserDefaults(nil), '
        'timedEntries: [])',
      ),
    );
    expect(
      content,
      contains(
        'data: MixedData.fromUserDefaults(prefs, at: now, timedEntries: timedEntries),\n'
        '        timedEntries: timedEntries',
      ),
    );
    expect(
      content,
      contains(
        'data: MixedData.fromUserDefaults(prefs, at: timedEntry.date, '
        'timedEntries: timedEntries),\n'
        '          timedEntries: timedEntries',
      ),
    );
    // Argument labels agree with the emitted signature and with getTimeline.
    expect(
      content,
      contains('  static func fromUserDefaults(\n'
          '    _ defaults: UserDefaults?,\n'
          '    at date: Date = Date(),\n'
          '    timedEntries: [(date: Date, values: [String: Any])]? = nil\n'
          '  ) -> MixedData {'),
    );
    expect(
      content,
      contains(
        'data: MixedData.fromUserDefaults(prefs, at: timedEntry.date, '
        'timedEntries: timedEntries)',
      ),
    );
  });

  test('re-reads at render time only for localized specs without timed fields',
      () async {
    const greeting = HWLocalizedString(
      'greeting',
      defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
    );
    const tree = HWText(greeting);
    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'Localized',
        widget: tree,
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
        localization: HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'Localized',
      dataFields: const [greeting],
      widgetTree: tree,
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/LocalizedHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // No timeline to walk, so there is no entry date to pass.
    expect(
      content,
      contains('let data = LocalizedData.fromUserDefaults(prefs)'),
    );
    expect(content, isNot(contains('at: entry.date')));
  });

  test('resolves a timed localized field through the shared helpers', () async {
    const greeting = HWLocalizedString(
      'greeting',
      defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
    );
    const tree = HWText(HWTimedData(greeting));
    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'TimedLocalized',
        widget: tree,
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
        localization: HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'TimedLocalized',
      dataFields: const [HWTimedData(greeting)],
      widgetTree: tree,
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/TimedLocalizedHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // The compiled translations travel to the reader, which merges the stored
    // map over them before resolving once.
    expect(
      content,
      contains(
        'greeting: hwReadTimedLocalized(timedValues, "greeting", '
        '["en": "Hello", "de": "Hallo"], baseLocale: "en"),',
      ),
    );
    expect(
      content,
      contains('merged.merge(hwLocalizedEntries(stored)) { _, new in new }'),
    );
    expect(
      content,
      contains('return hwLocalize(merged, baseLocale: baseLocale)'),
    );

    // Resolution itself is the untimed one, not a second implementation.
    expect('func hwResolveLocalized('.allMatches(content).length, 1);
    expect(
      content,
      contains('return hwResolveLocalized(hwCurrentLocales(), values, '
          'baseLocale: baseLocale) ?? ""'),
    );
    // Nothing reads the field's own preferences key.
    expect(content, isNot(contains('func hwReadLocalized(')));
    expect(
      content,
      contains(
        'let data = TimedLocalizedData.fromUserDefaults(prefs, at: entry.date, '
        'timedEntries: entry.timedEntries)',
      ),
    );
    expect(content, contains('Text(data.greeting ?? "")'));
  });

  test('keeps single-entry timeline for specs without timed fields', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'ExampleWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
      ),
      className: 'ExampleWidget',
      dataFields: const [
        HWInt('count'),
        HWJson('fileKey', HWString('title')),
      ],
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/ExampleWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(
      content,
      contains(
        'completion(Timeline(entries: [ExampleWidgetHomeWidgetEntry(date: Date(), data: data)], policy: .atEnd))',
      ),
    );
    expect(
      content,
      contains(
        'static func fromUserDefaults(_ defaults: UserDefaults?) -> ExampleWidgetData {',
      ),
    );
    expect(content, isNot(contains('loadTimedEntries')));
    expect(content, isNot(contains('activeTimedValues')));
    expect(content, isNot(contains('timedData')));
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

    expect(
      content,
      contains(r'caption: (values["caption"] as? String) ?? "Say \"hello\"",'),
    );
  });
}
