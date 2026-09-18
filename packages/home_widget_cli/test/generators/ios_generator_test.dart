import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/fnv_hash.dart';
import 'package:home_widget_cli/src/util/font_resolver.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';
import '../helpers/mock_logger.dart';
import '../helpers/xcode_project.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ios_gen_test');
    writeRunnerXcodeProject(tempDir);
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
      contains(
        'let prefs = UserDefaults(suiteName: '
        'ExampleWidgetHomeWidgetFlavor.appGroupId)',
      ),
    );
    expect(
      content,
      contains(
        'enum ExampleWidgetHomeWidgetFlavor {\n'
        '  static let appGroupId = "group.com.example"\n'
        '}',
      ),
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
      contains(
        r'Text(entry.data.count.map { hwFormatDecimal(NSNumber(value: $0), '
        r'minFraction: nil, maxFraction: nil, grouping: true) } ?? "")',
      ),
    );
    expect(content, contains('.applyContainerBackground()'));
    expect(content, contains('func applyContainerBackground() -> some View'));
    expect(content, isNot(contains('func applyContainerBackground<T: View>')));
    expect(
      content,
      contains('containerBackground(.fill.tertiary, for: .widget)'),
    );
  });

  test('renders a missing number as empty text, a default as itself', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NumbersWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
      ),
      className: 'NumbersWidget',
      dataFields: const [
        HWInt('count'),
        HWDouble('ratio'),
        HWInt('score', defaultValue: 7),
      ],
      widgetTree: const HWColumn(
        children: [
          HWText(HWInt('count')),
          HWText(HWDouble('ratio')),
          HWText(HWInt('score', defaultValue: 7)),
        ],
      ),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/NumbersWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, contains('let count: Int?'));
    expect(content, contains('let ratio: Double?'));
    expect(
      content,
      contains(r'entry.data.count.map { hwFormatDecimal(NSNumber(value: $0), '
          r'minFraction: nil, maxFraction: nil, grouping: true) } ?? ""'),
    );
    expect(
      content,
      contains(r'entry.data.ratio.map { hwFormatDecimal(NSNumber(value: $0), '
          r'minFraction: nil, maxFraction: nil, grouping: true) } ?? ""'),
    );
    expect(
      content,
      contains('hwFormatDecimal(NSNumber(value: entry.data.score ?? 7), '
          'minFraction: nil, maxFraction: nil, grouping: true)'),
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
        'if let path = entry.data.avatar, let uiImage = hwDecodeImage(path, 100.0, 100.0) {',
      ),
    );
    expect(content, contains('Image(uiImage: uiImage)'));
    expect(content, contains('.frame(width: 100.0, height: 100.0)'));
    expect(
      content,
      contains('if let uiImage = hwDecodeImage("assets/logo.png", nil, nil) {'),
    );
    expect(content, contains('.aspectRatio(contentMode: .fill)'));

    // Both sources decode through one helper, emitted once, and ImageIO comes
    // along with it.
    expect(content, contains('import ImageIO'));
    expect('func hwDecodeImage('.allMatches(content).length, 1);
    expect(
      content,
      contains('kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,'),
    );
    expect(
      content,
      contains(
        '.appendingPathComponent("Frameworks/App.framework/flutter_assets")',
      ),
    );
  });

  test('emits nothing image-related when no HWImage is rendered', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'UnrenderedImage',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.image'),
      ),
      className: 'UnrenderedImage',
      dataFields: const [HWImageData('avatar')],
      widgetTree: const HWText.fixed('no image here'),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/UnrenderedImageHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // The path is still read into the data struct; nothing decodes it.
    expect(content, contains('let avatar: String?'));
    expect(content, isNot(contains('hwDecodeImage')));
    expect(content, isNot(contains('import ImageIO')));
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
        'let uiImage = hwDecodeImage(path, nil, nil) {',
      ),
    );
    // The image's timestamps drive the WidgetKit timeline like any timed field.
    expect(
      content,
      contains('for timedEntry in timedEntries where timedEntry.date > now {'),
    );
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
      contains('avatar: values["avatar"] as? String,'),
    );
    expect(
      content,
      contains(
        'if let path = entry.data.contact?.avatar, '
        'let uiImage = hwDecodeImage(path, nil, nil) {',
      ),
    );
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
      contains('hwDecodeImage("packages/my_icons/assets/logo.png", nil, nil)'),
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
    expect(content, isNot(contains('VStack')));
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
    expect(content, contains('VStack(alignment: .center) {'));
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
      contains(
        r'Text(entry.data.value.map { hwFormatDecimal(NSNumber(value: $0), '
        r'minFraction: nil, maxFraction: nil, grouping: true) } ?? "")',
      ),
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

  test('generates a widgetURL with the homeWidget parameter appended',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'LinkedWidget',
        widgetUrl: 'myapp://linked?section=main',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.linked'),
      ),
      className: 'LinkedWidget',
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/LinkedWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(
      content,
      contains(
        '.widgetURL(URL(string: "myapp://linked?section=main&homeWidget"))',
      ),
    );
    // The modifier belongs to the view, not the widget configuration.
    expect(
      content,
      contains(
        '    .applyContainerBackground()\n'
        '    .widgetURL(URL(string: "myapp://linked?section=main&homeWidget"))',
      ),
    );
  });

  test('prefers the iOS widgetUrl over the top-level one', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'OverrideWidget',
        widgetUrl: 'myapp://shared',
        iOS: HomeWidgetIOSConfiguration(
          groupId: 'group.override',
          widgetUrl: 'myapp://ios',
        ),
      ),
      className: 'OverrideWidget',
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/OverrideWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(
      content,
      contains('.widgetURL(URL(string: "myapp://ios?homeWidget"))'),
    );
    expect(content, isNot(contains('myapp://shared')));
  });

  test('emits no widgetURL when none is configured', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'PlainWidget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.plain'),
      ),
      className: 'PlainWidget',
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/PlainWidgetHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, isNot(contains('.widgetURL(')));
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
    final mockLogger = useMockLogger();

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

  test('fails without an Xcode project in ios/ and writes nothing', () async {
    final iosDir = Directory(p.join(tempDir.path, 'ios'));
    Directory(p.join(iosDir.path, 'Runner.xcodeproj'))
        .deleteSync(recursive: true);
    final generator = IosGenerator(
      spec: WidgetSpec(
        data: HomeWidget(
          name: 'X',
          iOS: HomeWidgetIOSConfiguration(groupId: 'g'),
        ),
        className: 'X',
      ),
      projectRoot: tempDir,
    );
    final noProject = throwsA(
      isA<GeneratorError>().having(
        (e) => e.message,
        'message',
        startsWith('No Xcode project found in ${iosDir.path}.'),
      ),
    );

    await expectLater(generator.checkXcodeProject(), noProject);
    await expectLater(generator.generate(), noProject);

    expect(iosDir.listSync(), isEmpty);
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

  test('emits the decimal helper once for a plain number text', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'PlainNumber',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.fmt'),
      ),
      className: 'PlainNumber',
      dataFields: const [HWInt('steps')],
      widgetTree: const HWText(HWInt('steps')),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/PlainNumberHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect('func hwFormatDecimal('.allMatches(content).length, 1);
    expect('func hwFormatLocale('.allMatches(content).length, 1);
    // The helper is declared after the one it calls.
    expect(
      content.indexOf('func hwFormatLocale('),
      lessThan(content.indexOf('func hwFormatDecimal(')),
    );
    // Nothing else is dragged in.
    expect(content, isNot(contains('func hwParseIsoDate(')));
    expect(content, isNot(contains('func hwResolveTimeZone(')));
    expect(content, isNot(contains('func hwFormatCurrency(')));
  });

  test('emits every helper a currency and zoned date reach, deps first',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'RichFormat',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.fmt'),
      ),
      className: 'RichFormat',
      dataFields: const [
        HWDouble('total'),
        HWString('currency'),
        HWDateTime('when'),
        HWString('tz'),
      ],
      widgetTree: const HWColumn(
        children: [
          HWText.number(
            HWDouble('total'),
            format: HWNumberFormat.currency(
              currency: HWCurrency.data(HWString('currency')),
            ),
          ),
          HWText.dateTime(
            HWDateTime('when'),
            format: HWDateFormat.yMMMd,
            timeZone: HWTimeZone.data(HWString('tz')),
          ),
        ],
      ),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/RichFormatHomeWidget/Widget.swift'),
    ).readAsStringSync();

    for (final helper in [
      'hwFormatLocale',
      'hwResolveTimeZone',
      'hwParseIsoDate',
      'hwFormatCurrency',
      'hwFormatDateSkeleton',
    ]) {
      expect(
        'func $helper('.allMatches(content).length,
        1,
        reason: '$helper should be emitted exactly once',
      );
    }
    expect(content, isNot(contains('func hwFormatDecimal(')));

    expect(
      content.indexOf('func hwFormatLocale('),
      lessThan(content.indexOf('func hwFormatCurrency(')),
    );
    expect(
      content.indexOf('func hwResolveTimeZone('),
      lessThan(content.indexOf('func hwFormatDateSkeleton(')),
    );

    expect(
      content,
      contains(
        r'Text(entry.data.total.map { hwFormatCurrency(NSNumber(value: $0), '
        r'code: entry.data.currency ?? "", decimals: nil) } ?? "")',
      ),
    );
    expect(
      content,
      contains(
        r'Text(entry.data.when.map { hwFormatDateSkeleton($0, "yMMMd", '
        'timeZone: entry.data.tz) } ?? "")',
      ),
    );
  });

  test('emits only the date parser for a date that is never rendered',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'DateGate',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.fmt'),
      ),
      className: 'DateGate',
      dataFields: const [HWDateTime('when')],
      widgetTree: const HWDataExists(
        data: HWDateTime('when'),
        whenPresent: HWText.fixed('yes'),
        whenAbsent: HWText.fixed('no'),
      ),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/DateGateHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect('func hwParseIsoDate('.allMatches(content).length, 1);
    expect(content, isNot(contains('func hwFormatLocale(')));
    expect(content, isNot(contains('func hwResolveTimeZone(')));
    expect(content, isNot(contains('func hwFormatDate')));
  });

  test('emits no formatting helper for a widget without numbers or dates',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TextOnly',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.fmt'),
      ),
      className: 'TextOnly',
      dataFields: const [HWString('title'), HWBool('done')],
      widgetTree: const HWText(HWString('title')),
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/TextOnlyHomeWidget/Widget.swift'),
    ).readAsStringSync();

    expect(content, isNot(contains('hwFormat')));
    expect(content, isNot(contains('hwParseIsoDate')));
    expect(content, isNot(contains('hwResolveTimeZone')));
  });

  test('parses dates out of every place they are stored', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'DatePlaces',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.fmt'),
      ),
      className: 'DatePlaces',
      dataFields: const [
        HWDateTime('when'),
        HWTimedData(HWDateTime('shiftStart')),
        HWJson('order', HWDateTime('placedAt')),
        HWTimedData(HWJson('slot', HWDateTime('at'))),
      ],
    );

    await IosGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(tempDir.path, 'ios/DatePlacesHomeWidget/Widget.swift'),
    ).readAsStringSync();

    // Every date is a nullable Date on the struct it belongs to.
    expect(content, contains('  let when: Date?'));
    expect(content, contains('  let shiftStart: Date?'));
    expect(content, contains('  let placedAt: Date?'));
    expect(content, contains('  let at: Date?'));

    // Top level: read as a string from the preferences key.
    expect(
      content,
      contains(
        'when: hwParseIsoDate(defaults?.string('
        'forKey: "\\(paramPrefix).when") ?? ""),',
      ),
    );
    // Time-based: read from the entry active at the render instant, before the
    // generic cast that would look for a `Date`.
    expect(
      content,
      contains(
        'shiftStart: hwParseIsoDate((timedValues["shiftStart"] as? String) '
        '?? ""),',
      ),
    );
    expect(content, isNot(contains('as? Date')));
    // JSON leaves, timed and untimed, go through the same decoder.
    expect(
      content,
      contains(
        'placedAt: hwParseIsoDate((values["placedAt"] as? String) ?? ""),',
      ),
    );
    expect(
      content,
      contains('at: hwParseIsoDate((values["at"] as? String) ?? ""),'),
    );
  });

  group('flavors', () {
    WidgetSpec specFor(Map<String, HomeWidgetFlavor> flavors) => WidgetSpec(
          data: HomeWidget(
            name: 'Greeting',
            iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
            flavors: flavors,
          ),
          className: 'Greeting',
        );

    File writePbxproj(
      List<RunnerFlavor> flavors, {
      String? baseEntitlements,
    }) =>
        writeRunnerXcodeProject(
          tempDir,
          flavors: flavors,
          baseEntitlements: baseEntitlements,
        );

    String readIos(String relative) =>
        File(p.join(tempDir.path, 'ios', relative)).readAsStringSync();

    test('emits the flavor enum and guards the bundle', () async {
      writePbxproj(const [_devNoEntitlements, _prodFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
          'prod': const HomeWidgetFlavor(),
        }),
        projectRoot: tempDir,
      ).generate();

      final widget = readIos('GreetingHomeWidget/Widget.swift');
      expect(
        widget,
        contains(
          'enum GreetingHomeWidgetFlavor {\n'
          '  #if HW_FLAVOR_DEV\n'
          '  static let appGroupId = "group.example.dev"\n'
          '  #elseif HW_FLAVOR_PROD\n'
          '  static let appGroupId = "group.example"\n'
          '  #else\n'
          '  static let appGroupId = "group.example"\n'
          '  #endif\n'
          '}',
        ),
      );
      expect(widget, isNot(contains('suiteName: "group.')));

      expect(
        readIos('GreetingHomeWidget/WidgetBundle.swift'),
        contains(
          '    #if HW_FLAVOR_DEV || HW_FLAVOR_PROD\n'
          '    GreetingHomeWidget()\n'
          '    #endif',
        ),
      );
    });

    test('writes one entitlements file per flavor next to the base one',
        () async {
      writePbxproj(const [_devNoEntitlements, _prodFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
          'prod': const HomeWidgetFlavor(),
        }),
        projectRoot: tempDir,
      ).generate();

      expect(
        readIos('GreetingHomeWidget.entitlements'),
        contains('<string>group.example</string>'),
      );
      expect(
        readIos('GreetingHomeWidget.dev.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      expect(
        readIos('GreetingHomeWidget.dev.entitlements'),
        isNot(contains('<string>group.example</string>')),
      );
      expect(
        readIos('GreetingHomeWidget.prod.entitlements'),
        contains('<string>group.example</string>'),
      );
    });

    test('signs each flavored extension configuration with its own file',
        () async {
      final pbxproj = writePbxproj(const [_devFlavor, _prodFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
          'prod': const HomeWidgetFlavor(),
        }),
        projectRoot: tempDir,
      ).generate();

      final text = pbxproj.readAsStringSync();
      for (final name in const ['Debug-dev', 'Release-dev', 'Profile-dev']) {
        expect(
          _extensionConfig(text, name),
          contains(
            'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
          ),
        );
      }
      expect(
        _extensionConfig(text, 'Debug-prod'),
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.prod.entitlements;',
        ),
      );
      expect(
        _extensionConfig(text, 'Debug'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
    });

    test("adds a flavor's group to the Runner file its configuration names",
        () async {
      writePbxproj(const [_devFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      expect(
        readIos('Runner/RunnerDev.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      final base = readIos('Runner/Runner.entitlements');
      expect(base, contains('<string>group.example</string>'));
      expect(base, isNot(contains('<string>group.example.dev</string>')));
    });

    test("adds a flavor's group to every file its configurations name",
        () async {
      writePbxproj(const [_splitDevFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      // Debug-dev and Release-dev sign with different files, so a group written
      // to only one of them would be missing from the other's builds.
      expect(
        readIos('Runner/RunnerDevDebug.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      expect(
        readIos('Runner/RunnerDevRelease.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      expect(
        readIos('Runner/Runner.entitlements'),
        isNot(contains('<string>group.example.dev</string>')),
      );
    });

    test('follows a flavor whose Debug configuration names no file', () async {
      writePbxproj(const [_releaseOnlyDevFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      expect(
        readIos('Runner/RunnerDevRelease.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      // Debug-dev and Profile-dev were given Runner/Runner.entitlements before
      // this ran, so they carry the group there.
      expect(
        readIos('Runner/Runner.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
    });

    test('keeps the resolvable files of a flavor with one it cannot locate',
        () async {
      writePbxproj(const [_partlyCustomDevFlavor]);
      final mock = useMockLogger();

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains(r'$(CUSTOM)/RunnerDev.entitlements'),
              contains('group.example.dev'),
            ),
          ),
        ),
      ).called(1);
      expect(
        readIos('Runner/RunnerDevDebug.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      expect(
        readIos('Runner/RunnerDevProfile.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
      expect(
        File(p.join(tempDir.path, 'ios/RunnerDev.entitlements')).existsSync(),
        isFalse,
      );
    });

    test('notes the Runner entitlements file flavors have to share', () async {
      writePbxproj(const [_devNoEntitlements, _prodFlavor]);
      final mock = useMockLogger();

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
          'prod': const HomeWidgetFlavor(),
        }),
        projectRoot: tempDir,
      ).generate();

      final runner = readIos('Runner/Runner.entitlements');
      expect(runner, contains('<string>group.example</string>'));
      expect(runner, contains('<string>group.example.dev</string>'));
      verify(
        () => mock.info(
          any(
            that: allOf(
              contains('Runner/Runner.entitlements'),
              contains('several App Groups'),
            ),
          ),
        ),
      ).called(1);
    });

    test('fails on a flavor the Xcode project does not have', () async {
      writePbxproj(const [_devFlavor]);

      await expectLater(
        IosGenerator(
          spec: specFor({'stg': const HomeWidgetFlavor()}),
          projectRoot: tempDir,
        ).generate(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Greeting'),
              contains('"stg"'),
              contains('Debug-stg, Release-stg and Profile-stg'),
              contains('"dev"'),
            ),
          ),
        ),
      );
    });

    test('writes nothing when a declared flavor is missing', () async {
      writePbxproj(const [_devFlavor]);
      final before = File(
        p.join(tempDir.path, 'ios/Runner.xcodeproj/project.pbxproj'),
      ).readAsStringSync();

      await expectLater(
        IosGenerator(
          spec: specFor({'stg': const HomeWidgetFlavor()}),
          projectRoot: tempDir,
        ).generate(),
        throwsA(isA<GeneratorError>()),
      );

      // The guard runs before the first write, so neither the extension folder
      // nor the entitlements files exist and the project is untouched.
      expect(
        Directory(p.join(tempDir.path, 'ios/GreetingHomeWidget')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(tempDir.path, 'ios/GreetingHomeWidget.entitlements'))
            .existsSync(),
        isFalse,
      );
      expect(
        File(p.join(tempDir.path, 'ios/Runner.xcodeproj/project.pbxproj'))
            .readAsStringSync(),
        before,
      );
    });

    for (final (description, flavors) in [
      ('a flavored', {'dev': const HomeWidgetFlavor()}),
      ('an unflavored', const <String, HomeWidgetFlavor>{}),
    ]) {
      test('fails $description widget on an Xcode project it cannot read',
          () async {
        final pbxproj = File(
          p.join(tempDir.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        )..parent.createSync(recursive: true);
        pbxproj.writeAsStringSync('not a property list');

        await expectLater(
          IosGenerator(spec: specFor(flavors), projectRoot: tempDir).generate(),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              allOf(
                startsWith(
                  'Could not read the Xcode project ${pbxproj.path}: ',
                ),
                contains('line 1'),
              ),
            ),
          ),
        );
        expect(
          Directory(p.join(tempDir.path, 'ios/GreetingHomeWidget'))
              .existsSync(),
          isFalse,
        );
        expect(
          File(p.join(tempDir.path, 'ios/GreetingHomeWidget.entitlements'))
              .existsSync(),
          isFalse,
        );
        expect(
          File(p.join(tempDir.path, 'ios/Runner/Runner.entitlements'))
              .existsSync(),
          isFalse,
        );
        expect(pbxproj.readAsStringSync(), 'not a property list');
      });
    }

    test('stays quiet about flavors it declares and the project has', () async {
      writePbxproj(const [_devFlavor]);
      final mock = useMockLogger();

      await IosGenerator(
        spec: specFor({'dev': const HomeWidgetFlavor()}),
        projectRoot: tempDir,
      ).generate();

      verifyNever(() => mock.warn(any(that: contains('flavor'))));
      verifyNever(() => mock.info(any(that: contains('App Groups'))));
    });

    test('notes an Xcode flavor the widget leaves out', () async {
      writePbxproj(const [_devFlavor, _prodFlavor]);
      final mock = useMockLogger();

      await IosGenerator(
        spec: specFor({'dev': const HomeWidgetFlavor()}),
        projectRoot: tempDir,
      ).generate();

      verify(
        () => mock.detail(
          any(
            that: contains(
              'Greeting is not generated for the Xcode flavor "prod"',
            ),
          ),
        ),
      ).called(1);
    });

    test('resolves a Runner entitlements path written with build variables',
        () async {
      writePbxproj(const [_srcRootDevFlavor]);

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      expect(
        readIos('Runner/RunnerDev.entitlements'),
        contains('<string>group.example.dev</string>'),
      );
    });

    test('leaves an entitlements file only Xcode can locate to the user',
        () async {
      writePbxproj(const [_customPathDevFlavor]);
      final mock = useMockLogger();

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains(r'$(CUSTOM)/RunnerDev.entitlements'),
              contains('group.example.dev'),
            ),
          ),
        ),
      ).called(1);
      // Nothing is guessed: no file is created, and the group does not end up
      // in the shared one either.
      expect(
        File(p.join(tempDir.path, 'ios/RunnerDev.entitlements')).existsSync(),
        isFalse,
      );
      expect(
        readIos('Runner/Runner.entitlements'),
        isNot(contains('<string>group.example.dev</string>')),
      );
    });

    test('writes the base group next to the app without unflavored ones',
        () async {
      final pbxproj = writePbxproj(const [_devNoEntitlements]);
      pbxproj.writeAsStringSync(
        pbxproj
            .readAsStringSync()
            .replaceAll(
              RegExp(r'\t\t\t\t97C1470[0-2]1CF9000F007C117D /\* \w+ \*/,\n'),
              '',
            )
            .replaceAll('Runner/Info.plist', 'App/Info.plist'),
      );

      await IosGenerator(
        spec: specFor({
          'dev': const HomeWidgetFlavor(
            iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
          ),
        }),
        projectRoot: tempDir,
      ).generate();

      expect(
        readIos('App/App.entitlements'),
        allOf(
          contains('<string>group.example</string>'),
          contains('<string>group.example.dev</string>'),
        ),
      );
      expect(
        File(p.join(tempDir.path, 'ios/Runner/Runner.entitlements'))
            .existsSync(),
        isFalse,
      );
    });

    test('writes the base group into the file Runner actually signs with',
        () async {
      writePbxproj(
        const [],
        baseEntitlements: 'Runner/MyApp.entitlements',
      );

      await IosGenerator(spec: specFor(const {}), projectRoot: tempDir)
          .generate();

      expect(
        readIos('Runner/MyApp.entitlements'),
        contains('<string>group.example</string>'),
      );
      expect(
        File(p.join(tempDir.path, 'ios/Runner/Runner.entitlements'))
            .existsSync(),
        isFalse,
      );
    });
  });

  group('icon font resources', () {
    const fontFileName = 'hw_font_icons_brandicons__brand_icons.otf';
    const iconFont = HWIconFont(family: 'BrandIcons', package: 'brand_icons');
    const moodIcons = HWIconData.resolved(
      'mood',
      entries: [HWIconEntry('happy', 0xE88A)],
      iconFont: iconFont,
      defaultValue: 0xE88A,
    );
    const icon = HWIcon.resolved(moodIcons, fontResourcePrefix: 'hw_font_mood');

    setUp(() {
      final package = writeFontPackage(
        tempDir,
        'brand_icons',
        pubspecFonts: '''
    - family: BrandIcons
      fonts:
        - asset: fonts/BrandIcons.otf
''',
        assets: ['fonts/BrandIcons.otf'],
      );
      writeFontFixture(
        tempDir,
        packages: [FixturePackage(name: 'brand_icons', root: package.path)],
      );
      resetFontResolverCaches();
      addTearDown(resetFontResolverCaches);
    });

    test('wires the copied font into the extension Resources build phase',
        () async {
      final pbxprojFile = writeRunnerXcodeProject(tempDir);

      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'Greeting',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
          widget: icon,
        ),
        className: 'Greeting',
        dataFields: const [moodIcons],
        widgetTree: icon,
      );

      await IosGenerator(spec: spec, projectRoot: tempDir).generate();

      expect(
        File(p.join(tempDir.path, 'ios/GreetingHomeWidget', fontFileName))
            .existsSync(),
        isTrue,
      );

      final text = pbxprojFile.readAsStringSync();
      final fileRefId = xcodeObjectId(
        'fileref:$fontFileName:GreetingHomeWidget',
      );
      final buildFileId = xcodeObjectId(
        'buildfile:$fontFileName:GreetingHomeWidget',
      );

      expect(
        text,
        contains(
          '$buildFileId /* $fontFileName in Resources */ = '
          '{isa = PBXBuildFile; fileRef = $fileRefId /* $fontFileName */; };',
        ),
      );

      final phaseId = xcodeObjectId('phase:resources:GreetingHomeWidget');
      final phase = RegExp(
        '$phaseId /\\* Resources \\*/ = \\{[\\s\\S]*?\\n\\t\\t\\};',
      ).firstMatch(text);
      expect(phase, isNotNull, reason: 'no extension Resources build phase');
      expect(
        phase!.group(0),
        contains('$buildFileId /* $fontFileName in Resources */,'),
      );
    });
  });

  group('string catalog resources', () {
    test('wires the written catalog into the extension target', () async {
      final pbxprojFile = writeRunnerXcodeProject(tempDir);

      // ignore: invalid_use_of_internal_member
      const greeting = HWLocalizedString.resolved(
        '',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
        isConstant: true,
        defaultLocale: 'en',
        resourcePrefix: 'home_widget_greeting',
      );
      const tree = HWText(greeting);

      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'Greeting',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
          widget: tree,
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'Greeting',
        dataFields: tree.dataDependencies.toList(),
        widgetTree: tree,
      );

      await IosGenerator(spec: spec, projectRoot: tempDir).generate();

      expect(
        File(
          p.join(tempDir.path, 'ios/GreetingHomeWidget/Localizable.xcstrings'),
        ).existsSync(),
        isTrue,
      );

      final text = pbxprojFile.readAsStringSync();
      expect(
        text,
        contains('lastKnownFileType = text.json.xcstrings; '
            'path = Localizable.xcstrings;'),
      );
      final regions =
          RegExp(r'knownRegions = \(([\s\S]*?)\);').firstMatch(text)!.group(1)!;
      expect(regions, contains('de,'));
    });

    test('leaves the project alone when no catalog is written', () async {
      final pbxprojFile = writeRunnerXcodeProject(tempDir);

      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'Greeting',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
        ),
        className: 'Greeting',
      );

      await IosGenerator(spec: spec, projectRoot: tempDir).generate();

      expect(
        pbxprojFile.readAsStringSync(),
        isNot(contains('Localizable.xcstrings')),
      );
    });
  });

  group('size-adaptive widgets', () {
    Future<String> generate(
      HWWidget tree, {
      List<HWWidgetFamily>? families,
    }) async {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'Adaptive',
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.adaptive',
            supportedFamilies: families,
          ),
        ),
        className: 'Adaptive',
        widgetTree: tree,
      );

      await IosGenerator(spec: spec, projectRoot: tempDir).generate();
      return File(
        p.join(tempDir.path, 'ios/AdaptiveHomeWidget/Widget.swift'),
      ).readAsStringSync();
    }

    test('appends every family newer than the deployment target', () async {
      final content = await generate(
        HWText.fixed('S'),
        families: HWWidgetFamily.values,
      );

      expect(
        content,
        contains(
          '  private var supportedFamilies: [WidgetFamily] {\n'
          '    var families: [WidgetFamily] = '
          '[.systemSmall, .systemMedium, .systemLarge]\n'
          '    if #available(iOSApplicationExtension 15.0, *) {\n'
          '      families.append(.systemExtraLarge)\n'
          '    }\n'
          '    if #available(iOSApplicationExtension 16.0, *) {\n'
          '      families.append(contentsOf: '
          '[.accessoryCircular, .accessoryRectangular, .accessoryInline])\n'
          '    }\n'
          '    #if compiler(>=6.4)\n'
          '      if #available(iOSApplicationExtension 27.0, *) {\n'
          '        families.append(.systemExtraLargePortrait)\n'
          '      }\n'
          '    #endif\n'
          '    return families\n'
          '  }\n',
        ),
      );
      expect(content, contains('.supportedFamilies(supportedFamilies)'));
    });

    test('keeps a plain literal when no family needs a gate', () async {
      final content = await generate(
        HWText.fixed('S'),
        families: const [
          HWWidgetFamily.systemSmall,
          HWWidgetFamily.systemLarge,
        ],
      );

      expect(
        content,
        contains('.supportedFamilies([.systemSmall, .systemLarge])'),
      );
      expect(content, isNot(contains('private var supportedFamilies')));
    });

    test('wraps a root switch in a Group before the modifier', () async {
      final content = await generate(
        HWSizeAdaptive(
          small: HWText.fixed('S'),
          medium: HWText.fixed('M'),
        ),
      );

      expect(
        content,
        contains(
          '    Group {\n'
          '            switch widgetFamily {\n'
          '            case .systemMedium, .systemLarge:\n'
          '                Text("M")\n'
          '            default:\n'
          '                Text("S")\n'
          '            }\n'
          '    }\n'
          '    .applyContainerBackground()',
        ),
      );
      expect(
        content,
        contains('@Environment(\\.widgetFamily) var widgetFamily'),
      );
    });

    test('collapses to one layout when only one family is reachable', () async {
      final content = await generate(
        HWSizeAdaptive(
          small: HWText.fixed('S'),
          medium: HWText.fixed('M'),
        ),
        families: const [HWWidgetFamily.systemSmall],
      );

      expect(content, isNot(contains('switch widgetFamily')));
      expect(content, isNot(contains('Text("M")')));
      expect(content, contains('        Text("S")\n    .applyContainer'));
    });

    test(
        'defaults to the first accessory family when only those are '
        'reachable', () async {
      final content = await generate(
        HWSizeAdaptive(
          accessoryCircular: HWText.fixed('C'),
          accessoryRectangular: HWText.fixed('R'),
        ),
        families: const [
          HWWidgetFamily.accessoryCircular,
          HWWidgetFamily.accessoryRectangular,
        ],
      );

      expect(
        content,
        contains(
          '            switch widgetFamily {\n'
          '            case .accessoryRectangular:\n'
          '                Text("R")\n'
          '            default:\n'
          '                Text("C")\n'
          '            }',
        ),
      );
    });
  });
}

const _devFlavor = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: 'Runner/RunnerDev.entitlements',
);
const _devNoEntitlements = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
);
const _prodFlavor = RunnerFlavor(
  name: 'prod',
  idPrefix: 'BB',
  bundleId: 'com.example.app',
);

/// A flavor whose entitlements path is written the way Xcode writes it once it
/// has touched the setting: quoted, and rooted at the project directory.
const _srcRootDevFlavor = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: r'"$(SRCROOT)/Runner/RunnerDev.entitlements"',
);

/// A flavor signing with a file only Xcode can locate.
const _customPathDevFlavor = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: r'"$(CUSTOM)/RunnerDev.entitlements"',
);

/// A flavor whose Debug configuration signs with a different file than its
/// Release and Profile ones.
const _splitDevFlavor = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: 'Runner/RunnerDevRelease.entitlements',
  entitlementsByConfiguration: {'Debug': 'Runner/RunnerDevDebug.entitlements'},
);

/// A flavor only its Release configuration gives an entitlements file.
const _releaseOnlyDevFlavor = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlementsByConfiguration: {
    'Release': 'Runner/RunnerDevRelease.entitlements',
  },
);

/// A flavor whose Release configuration alone names a file only Xcode can
/// locate.
const _partlyCustomDevFlavor = RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlementsByConfiguration: {
    'Debug': 'Runner/RunnerDevDebug.entitlements',
    'Release': r'"$(CUSTOM)/RunnerDev.entitlements"',
    'Profile': 'Runner/RunnerDevProfile.entitlements',
  },
);

/// The extension's build configuration object named [name], as written text.
String _extensionConfig(String pbxproj, String name) {
  final id = xcodeObjectId('cfg:$name:GreetingHomeWidget');
  final match = RegExp(
    '$id /\\* ${RegExp.escape(name)} \\*/ = \\{[\\s\\S]*?\\n\\t\\t\\};',
  ).firstMatch(pbxproj);
  expect(
    match,
    isNotNull,
    reason: 'no extension build configuration named "$name"',
  );
  return match!.group(0)!;
}
