import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
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
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.success(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);

    tempDir = Directory.systemTemp.createTempSync('android_gen_test');
    // Setup android/app structure
    Directory(p.join(tempDir.path, 'android', 'app'))
        .createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('skips when android/app directory is absent', () async {
    final root = Directory.systemTemp.createTempSync('android_gen_no_app');
    addTearDown(() => root.deleteSync(recursive: true));

    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'N',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      ),
      className: 'N',
    );

    await AndroidGenerator(spec: spec, projectRoot: root).generate();

    verify(
      () => mockLogger.warn(any(that: contains('android/app/ not found'))),
    ).called(1);
  });

  test('emits bare widget tree without GlanceTheme when useGlanceTheme false',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'No Theme',
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.notheme',
          useGlanceTheme: false,
        ),
      ),
      className: 'NoThemeWidget',
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final kt = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/notheme/NoThemeWidgetHomeWidget.kt',
      ),
    );
    final content = kt.readAsStringSync();
    expect(content, isNot(contains('GlanceTheme {')));
    expect(content, contains('GlanceTheme.colors'));
  });

  test('appends description string into existing strings.xml via update path',
      () async {
    final stringsDir = Directory(
      p.join(
        tempDir.path,
        'android',
        'app',
        'src',
        'main',
        'res',
        'values',
      ),
    )..createSync(recursive: true);
    File(p.join(stringsDir.path, 'strings.xml')).writeAsStringSync(
      '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="existing_only">existing</string>
</resources>
''',
    );

    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'DescAppend',
        description: 'From unit test strings patch',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      ),
      className: 'DescAppend',
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content =
        File(p.join(stringsDir.path, 'strings.xml')).readAsStringSync();
    expect(content, contains('name="desc_append_home_widget_description"'));
  });

  test('escapes literal dollar signs in Kotlin string defaults', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'DollarWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.buck'),
      ),
      className: 'DollarWidget',
      dataFields: const [
        HWJson(
          'j',
          HWString('price', defaultValue: '\$9.99'),
        ),
      ],
      widgetTree: const HWText(
        HWJson(
          'j',
          HWString('price', defaultValue: '\$9.99'),
        ),
      ),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final kt = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/buck/DollarWidgetHomeWidget.kt',
      ),
    );
    expect(
      kt.readAsStringSync(),
      contains(r'"\$9.99"'),
    );
  });

  test('generates JSONObject optInt for HWInt JSON leaves', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'JsonIntLeaf',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.jsonint'),
      ),
      className: 'JsonIntLeaf',
      dataFields: const [
        HWJson('jf', HWInt('hits', defaultValue: 10)),
      ],
      widgetTree: const HWText(
        HWJson('jf', HWInt('hits', defaultValue: 10)),
      ),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final kt = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/jsonint/JsonIntLeafHomeWidget.kt',
      ),
    );
    expect(
      kt.readAsStringSync(),
      contains('optInt'),
    );
  });

  test('generates JSONObject optDouble for HWDouble JSON leaves', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'JsonDoubleLeaf',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.jsondbl'),
      ),
      className: 'JsonDoubleLeaf',
      dataFields: const [
        HWJson('jf', HWDouble('ratio', defaultValue: 1.5)),
      ],
      widgetTree: const HWText(
        HWJson('jf', HWDouble('ratio', defaultValue: 1.5)),
      ),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final kt = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/jsondbl/JsonDoubleLeafHomeWidget.kt',
      ),
    );
    expect(kt.readAsStringSync(), contains('optDouble'));
  });

  test('generates Kotlin widget with data class', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'ExampleWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      ),
      className: 'ExampleWidget',
      dataFields: [
        HWInt('count'),
        HWString('label'),
      ],
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/example/ExampleWidgetHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(content, contains('data class ExampleWidgetData('));
    expect(content, contains('val count: Int? = null,'));
    expect(content, contains('val label: String? = null,'));
    expect(
      content,
      contains(
        'fun fromPreferences(prefs: android.content.SharedPreferences): ExampleWidgetData',
      ),
    );
    expect(
      content,
      contains(
        'if (prefs.contains("\${PREFERENCES_PREFIX}.count")) prefs.getInt("\${PREFERENCES_PREFIX}.count", 0) else null',
      ),
    );
    expect(
      content,
      contains('prefs.getString("\${PREFERENCES_PREFIX}.label", null)'),
    );

    // Check usage in UI
    expect(
      content,
      contains('val widgetData = ExampleWidgetData.fromPreferences(prefs)'),
    );
    expect(
      content,
      contains('Text(text = "count: ")'),
    );
    expect(
      content,
      contains('Text(text = (widgetData.count?.toString() ?: "0"))'),
    );
  });

  test('generates Kotlin widget with JSON data classes', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'JsonWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      ),
      className: 'JsonWidget',
      dataFields: const [
        HWJson('fileKey', HWString('title')),
        HWJson('fileKey', HWBool('enabled', defaultValue: false)),
        HWJson('settings', HWBool('compact', defaultValue: true)),
      ],
      widgetTree: const HWBoolConditional(
        data: HWJson('fileKey', HWBool('enabled', defaultValue: false)),
        whenTrue: HWText.fixed('Enabled'),
        whenFalse: HWText.fixed('Disabled'),
      ),
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/example/JsonWidgetHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(
      content,
      contains('val fileKey: JsonWidgetFileKeyJsonData? = null,'),
    );
    expect(
      content,
      contains(
        'fileKey = JsonWidgetFileKeyJsonData.fromPath(prefs.getString("\${PREFERENCES_PREFIX}.fileKey", null)),',
      ),
    );
    expect(content, contains('data class JsonWidgetFileKeyJsonData('));
    expect(content, contains('val enabled: Boolean = false,'));
    expect(content, contains('import org.json.JSONObject'));
    expect(
      content,
      contains('if ((widgetData.fileKey?.enabled ?: false) == true) {'),
    );
  });

  test('generates Kotlin widget with nested JSON lookups from root file',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NestedJsonWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
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

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/example/NestedJsonWidgetHomeWidget.kt',
      ),
    );
    final content = widgetFile.readAsStringSync();

    expect(
      content,
      contains('val user: NestedJsonWidgetFileKeyJsonDataUser? = null,'),
    );
    expect(
      content,
      contains('prefs.getString("\${PREFERENCES_PREFIX}.fileKey", null)'),
    );
    expect(
      content,
      contains(
        'NestedJsonWidgetFileKeyJsonDataUser.fromJson(json.optJSONObject("user"))',
      ),
    );
    expect(content, contains('val json = obj ?: org.json.JSONObject()'));
    expect(
      content,
      contains(
        'enabled = if (json.has("enabled") && !json.isNull("enabled")) '
        'json.optBoolean("enabled") else true,',
      ),
    );
    expect(
      content,
      contains('if ((widgetData.fileKey?.user?.enabled ?: true) == true) {'),
    );
  });

  test('generates provider info XML and strings.xml with v2 fields', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'V2Widget',
        description: 'A v2 widget description',
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.example.v2',
          minWidth: 100,
          minHeight: 50,
          minResizeWidth: 80,
          minResizeHeight: 40,
          maxResizeWidth: 200,
          maxResizeHeight: 100,
          targetCellWidth: 2,
          targetCellHeight: 1,
          resizeMode: HWAndroidResizeMode.horizontal,
          widgetCategory: HWAndroidWidgetCategory.keyguard,
          updatePeriodMillis: 3600000,
        ),
      ),
      className: 'V2Widget',
      dataFields: [],
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    // Check XML
    final xmlFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/res/xml/v2_widget_home_widget.xml',
      ),
    );
    expect(xmlFile.existsSync(), isTrue);
    final xmlContent = xmlFile.readAsStringSync();

    expect(xmlContent, contains('android:minWidth="100dp"'));
    expect(xmlContent, contains('android:minHeight="50dp"'));
    expect(xmlContent, contains('android:minResizeWidth="80dp"'));
    expect(xmlContent, contains('android:minResizeHeight="40dp"'));
    expect(xmlContent, contains('android:maxResizeWidth="200dp"'));
    expect(xmlContent, contains('android:maxResizeHeight="100dp"'));
    expect(xmlContent, contains('android:targetCellWidth="2"'));
    expect(xmlContent, contains('android:targetCellHeight="1"'));
    expect(xmlContent, contains('android:resizeMode="horizontal"'));
    expect(xmlContent, contains('android:widgetCategory="keyguard"'));
    expect(xmlContent, contains('android:updatePeriodMillis="3600000"'));
    expect(
      xmlContent,
      contains(
        'android:description="@string/v2_widget_home_widget_description"',
      ),
    );

    // Check Strings
    final stringsFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/res/values/strings.xml',
      ),
    );
    expect(stringsFile.existsSync(), isTrue);
    final stringsContent = stringsFile.readAsStringSync();
    expect(
      stringsContent,
      contains('name="v2_widget_home_widget_description"'),
    );
    expect(stringsContent, contains('>A v2 widget description<'));
    expect(stringsContent, contains('>A v2 widget description<'));
  });

  test('generates Kotlin widget with widget tree', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TreeWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.tree'),
      ),
      className: 'TreeWidget',
      dataFields: [
        HWString('title'),
      ],
      widgetTree: HWText(
        HWString('title'),
      ),
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/tree/TreeWidgetHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    // Should use the emitter output with widgetData variable
    expect(
      content,
      contains(
        'Box(modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground).padding(16.dp).fillMaxSize(), contentAlignment = Alignment.Center) {',
      ),
    );
    // Should NOT contain placeholder
    expect(
      content,
      isNot(contains('Text(text = "TreeWidgetHomeWidget")')),
    );
    expect(content, contains('GlanceTheme {'));
    expect(
      content,
      contains(
        'GlanceModifier.background(GlanceTheme.colors.widgetBackground)',
      ),
    );
    expect(content, contains('import androidx.glance.GlanceTheme'));
  });

  test('generates Kotlin widget with HWDataOnly as root widget', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'Simple Data',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
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

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/example/SimpleDataHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    // Should contain data class
    expect(content, contains('data class SimpleDataData('));
    expect(content, contains('val label: String? = null,'));
    expect(content, contains('val value: Int? = null,'));

    expect(
      content,
      contains(
        'Box(modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground).padding(16.dp).fillMaxSize(), contentAlignment = Alignment.Center) {',
      ),
    );
    expect(content, contains('GlanceTheme {'));
    expect(content, contains('Text(text = "Simple Data")'));
  });

  test(
      'generates Kotlin widget without padding when applyContentPadding is false',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NoPaddingWidget',
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.nopadding',
          applyContentPadding: false,
        ),
      ),
      className: 'NoPaddingWidget',
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/nopadding/NoPaddingWidgetHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(content, isNot(contains('.padding(16.dp)')));
    // Not necessarily asserting not importing padding because HWPadding could be inside, but here tree is default.
  });

  test('generates Kotlin widget with HWPadding', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'PaddingWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.padding'),
      ),
      className: 'PaddingWidget',
      widgetTree: HWPadding(
        padding: HWEdgeInsets.only(top: 10, left: 20),
        child: HWText(HWString('title')),
      ),
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/padding/PaddingWidgetHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(
      content,
      contains(
        'padding(start = 20.0.dp, top = 10.0.dp, end = 0.0.dp, bottom = 0.0.dp)',
      ),
    );
  });

  test(
      'generates Kotlin widget without fillMaxSize when fillWidgetContent is false',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NoFillWidget',
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.nofill',
          fillWidgetContent: false,
        ),
      ),
      className: 'NoFillWidget',
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/nofill/NoFillWidgetHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(content, isNot(contains('.fillMaxSize()')));
  });

  test('generates Kotlin widget with Conditional Root (Box fallback)',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'ConditionalRootWidget',
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.conditional',
          backgroundColor: HWFixedColor(0xFFFF0000),
          applyContentPadding: true,
        ),
      ),
      className: 'ConditionalRoot',
      dataFields: [HWBool('flag')],
      widgetTree: HWDataExists(
        data: HWBool('flag'),
        whenPresent: HWText.fixed('Yes'),
        whenAbsent: HWText.fixed('No'),
      ),
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    final widgetFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/conditional/ConditionalRootHomeWidget.kt',
      ),
    );

    expect(widgetFile.existsSync(), isTrue);
    final content = widgetFile.readAsStringSync();

    expect(
      content,
      contains('import androidx.glance.layout.Box'),
    );

    expect(
      content,
      contains(
        'Box(modifier = GlanceModifier.background(ColorProvider(day = Color(0xFFFF0000), night = Color(0xFFFF0000))).padding(16.dp).fillMaxSize(), contentAlignment = Alignment.Center) {',
      ),
    );
    expect(content, contains('if (widgetData.flag != null) {'));
  });
}
