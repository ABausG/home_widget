import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('android_gen_test');
    // Setup android/app structure
    Directory(p.join(tempDir.path, 'android', 'app'))
        .createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
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
        'Text(modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground), text = widgetData.title ?: "")',
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
        'Column(modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground).padding(16.dp).fillMaxSize()) {',
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
}
