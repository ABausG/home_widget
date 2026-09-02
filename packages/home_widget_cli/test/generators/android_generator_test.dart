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

  test('writes its own resource file and never touches the user strings.xml',
      () async {
    final valuesDir = Directory(
      p.join(tempDir.path, 'android', 'app', 'src', 'main', 'res', 'values'),
    )..createSync(recursive: true);
    final stringsFile = File(p.join(valuesDir.path, 'strings.xml'));
    // Styled markup, a comment, and the author's own indentation: everything a
    // whole-document reserialization would reflow. Pretty printing splits the
    // text around <b>, and aapt then ships "Hello world , welcome!".
    const original = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
  <!-- Greeting shown on the home screen. -->
  <string name="greeting">Hello <b>world</b>, welcome!</string>
  <string name="app_name">Example</string>
</resources>
''';
    stringsFile.writeAsStringSync(original);

    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'Styled',
        description: 'A description',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      ),
      className: 'Styled',
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    expect(stringsFile.readAsStringSync(), original);

    final owned = File(p.join(valuesDir.path, 'home_widget_styled.xml'));
    final afterFirst = owned.readAsStringSync();
    expect(
      afterFirst,
      contains('<string name="home_widget_styled_label">Styled</string>'),
    );
    expect(
      afterFirst,
      contains('<string name="home_widget_styled_description">A description'
          '</string>'),
    );

    // A second run has nothing to change, so it must not rewrite the file or
    // claim it did.
    clearInteractions(mockLogger);
    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    expect(owned.readAsStringSync(), afterFirst);
    expect(stringsFile.readAsStringSync(), original);
    verifyNever(
      () => mockLogger.detail(any(that: contains('home_widget_styled.xml'))),
    );
  });

  test('drops the owned file, and the directory, when a locale goes away',
      () async {
    WidgetSpec specFor(List<String> locales, Map<String, String> names) =>
        WidgetSpec(
          data: HomeWidget(
            name: 'Greeter',
            android: const HomeWidgetAndroidConfiguration(
              packageName: 'com.example',
            ),
            localization: HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: locales,
              name: names,
            ),
          ),
          className: 'Greeter',
        );

    await AndroidGenerator(
      spec: specFor(
        const ['en', 'de', 'fr'],
        const {'de': 'Begruesser', 'fr': 'Salutation'},
      ),
      projectRoot: tempDir,
    ).generate();

    final resDir = p.join(tempDir.path, 'android/app/src/main/res');
    final german = File(p.join(resDir, 'values-de/home_widget_greeter.xml'));
    final french = File(p.join(resDir, 'values-fr/home_widget_greeter.xml'));
    expect(
      german.readAsStringSync(),
      contains('<string name="home_widget_greeter_label">Begruesser</string>'),
    );
    expect(french.existsSync(), isTrue);

    // A file the generator does not own keeps its directory alive.
    File(p.join(resDir, 'values-fr/strings.xml')).writeAsStringSync(
      '<?xml version="1.0" encoding="utf-8"?>\n<resources />\n',
    );

    await AndroidGenerator(
      spec: specFor(const ['en'], const {}),
      projectRoot: tempDir,
    ).generate();

    expect(german.existsSync(), isFalse);
    expect(Directory(p.join(resDir, 'values-de')).existsSync(), isFalse);
    expect(french.existsSync(), isFalse);
    expect(Directory(p.join(resDir, 'values-fr')).existsSync(), isTrue);
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

  test('generates Kotlin widget with image data fields', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'ImageWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
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

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/ImageWidgetHomeWidget.kt',
      ),
    ).readAsStringSync();

    // Runtime image paths are plain nullable strings in the data class;
    // asset images are never stored.
    expect(content, contains('data class ImageWidgetData('));
    expect(content, contains('val avatar: String? = null,'));
    expect(content, isNot(contains('assetsLogoPng')));
    expect(
      content,
      contains(
        'avatar = prefs.getString("\${PREFERENCES_PREFIX}.avatar", null)',
      ),
    );

    // Imports required by the emitted Glance image code.
    expect(content, contains('import android.graphics.BitmapFactory'));
    expect(content, contains('import androidx.glance.Image'));
    expect(content, contains('import androidx.glance.ImageProvider'));
    expect(content, contains('import androidx.glance.layout.ContentScale'));
    expect(content, contains('import androidx.glance.layout.width'));
    expect(content, contains('import androidx.glance.layout.height'));
    // Imports already present in the template are not duplicated.
    expect(
      'import androidx.glance.GlanceModifier\n'.allMatches(content).length,
      1,
    );

    // Body renders both images from their stored paths.
    expect(
      content,
      contains(
        'widgetData.avatar?.let { path -> '
        'hwDecodeImageFile(context, path, 100.0, 100.0) }',
      ),
    );
    expect(content, contains('provider = ImageProvider(bitmap),'));
    expect(content, contains('contentScale = ContentScale.Fit,'));
    expect(
      content,
      contains('modifier = GlanceModifier.width(100.0.dp).height(100.0.dp),'),
    );
    expect(
      content,
      contains(
        'flutterAssetBitmap(context, "assets/logo.png", null, null)'
        '?.let { bitmap ->',
      ),
    );
    expect(content, contains('contentScale = ContentScale.Crop,'));

    // Both decode paths subsample through one shared helper, emitted once for
    // the whole file.
    expect(content, contains('inJustDecodeBounds = true'));
    expect(
      content,
      contains(
        'inSampleSize = hwImageSampleSize(context, bounds, widthDp, heightDp)',
      ),
    );
    expect('private fun hwImageSampleSize('.allMatches(content).length, 1);
    expect('private fun hwDecodeImageFile('.allMatches(content).length, 1);
    expect('private fun flutterAssetBitmap('.allMatches(content).length, 1);
  });

  test('emits the asset helper only when an asset image is present', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'RuntimeOnly',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
      ),
      className: 'RuntimeOnly',
      dataFields: const [HWImageData('avatar')],
      widgetTree: const HWImage(HWImageData('avatar')),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/RuntimeOnlyHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(content, isNot(contains('flutterAssetBitmap')));
    expect(content, contains('private fun hwDecodeImageFile('));
    expect(content, contains('private fun hwImageSampleSize('));
  });

  test('emits no file decoder when every image is an asset', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'AssetOnly',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
      ),
      className: 'AssetOnly',
      dataFields: const [HWImageData.asset('assets/logo.png')],
      widgetTree: const HWImage.asset('assets/logo.png'),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/AssetOnlyHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(content, contains('private fun flutterAssetBitmap('));
    expect(content, contains('private fun hwImageSampleSize('));
    expect(content, isNot(contains('hwDecodeImageFile')));
  });

  test('imports BitmapFactory when no HWImage is rendered', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'UnrenderedImage',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
      ),
      className: 'UnrenderedImage',
      dataFields: const [HWImageData('avatar')],
      widgetTree: const HWText.fixed('no image here'),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/UnrenderedImageHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(content, contains('private fun hwImageSampleSize('));
    expect(content, contains('import android.graphics.BitmapFactory'));
  });

  test('reads a timed image path out of the active entry', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TimedImage',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
      ),
      className: 'TimedImage',
      dataFields: const [HWTimedData(HWImageData('slide'))],
      widgetTree: const HWImage(HWTimedData(HWImageData('slide'))),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/TimedImageHomeWidget.kt',
      ),
    ).readAsStringSync();

    // The resolved value is a path string, read like any other timed value...
    expect(content, contains('val slide: String? = null,'));
    expect(
      content,
      contains(
        'slide = if (timedValues.has("slide") && !timedValues.isNull("slide")) '
        'timedValues.optString("slide") else null,',
      ),
    );
    // ...and rendered exactly like an untimed runtime image.
    expect(
      content,
      contains(
        'widgetData.slide?.let { path -> '
        'hwDecodeImageFile(context, path, null, null) }',
      ),
    );
    expect(content, isNot(contains('flutterAssetBitmap')));

    // A timed image makes the widget time-based, so the resolver ships and the
    // scheduled updates it needs are wired the same as for any timed field.
    expect(content, contains('private fun resolveTimedValues('));
  });

  test('reads an image leaf of a JSON group as a path', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'JsonImage',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
      ),
      className: 'JsonImage',
      dataFields: const [HWJson('contact', HWImageData('avatar'))],
      widgetTree: const HWImage(HWJson('contact', HWImageData('avatar'))),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/JsonImageHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(content, contains('val avatar: String? = null,'));
    expect(
      content,
      contains(
        'avatar = if (json.has("avatar") && !json.isNull("avatar")) '
        'json.optString("avatar") else null,',
      ),
    );
    expect(
      content,
      contains(
        'widgetData.contact?.avatar?.let { path -> '
        'hwDecodeImageFile(context, path, null, null) }',
      ),
    );
    expect(content, isNot(contains('flutterAssetBitmap')));
  });

  test('prefixes a package asset with packages/<package>', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'PackageAsset',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.image'),
      ),
      className: 'PackageAsset',
      dataFields: const [
        HWImageData.asset('assets/logo.png', package: 'my_icons'),
      ],
      widgetTree: const HWImage.asset('assets/logo.png', package: 'my_icons'),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/image/PackageAssetHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(
      content,
      contains(
        'flutterAssetBitmap(context, '
        '"packages/my_icons/assets/logo.png", null, null)',
      ),
    );
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
    // JSON plumbing names java.io/org.json fully qualified, so no import for
    // either is emitted.
    expect(content, isNot(contains('import org.json.JSONObject')));
    expect(content, isNot(contains('import java.io.File')));
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

  test('generates Kotlin widget with timed primitive data', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TimedWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.timed'),
      ),
      className: 'TimedWidget',
      dataFields: const [
        HWString('title'),
        HWTimedData(HWString('label')),
        HWTimedData(HWInt('temperature', defaultValue: 7)),
      ],
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/timed/TimedWidgetHomeWidget.kt',
      ),
    ).readAsStringSync();

    // Timed fields are regular data class properties.
    expect(content, contains('val label: String? = null,'));
    expect(content, contains('val temperature: Int? = null,'));

    // fromPreferences gains the resolution time only when timed fields exist.
    expect(
      content,
      contains(
        'fun fromPreferences(prefs: android.content.SharedPreferences, now: Long = System.currentTimeMillis()): TimedWidgetData {',
      ),
    );
    expect(
      content,
      contains('val timedValues = resolveTimedValues(prefs, now)'),
    );
    expect(
      content,
      contains(
        'label = if (timedValues.has("label") && !timedValues.isNull("label")) '
        'timedValues.optString("label") else null,',
      ),
    );
    expect(
      content,
      contains(
        'temperature = if (timedValues.has("temperature") && '
        '!timedValues.isNull("temperature")) '
        'timedValues.optInt("temperature") else 7,',
      ),
    );

    // Resolver: file path from prefs, greatest timestamp <= now.
    expect(
      content,
      contains(
        'private fun resolveTimedValues(prefs: android.content.SharedPreferences, now: Long): org.json.JSONObject {',
      ),
    );
    expect(
      content,
      contains(
        'val path = prefs.getString("\${PREFERENCES_PREFIX}.timedData", null) '
        '?: return org.json.JSONObject()',
      ),
    );
    expect(content, contains('val timestamp = key.toLongOrNull() ?: continue'));
    expect(
      content,
      contains(
        'if (timestamp <= now && (activeKey == null || timestamp > activeTimestamp)) {',
      ),
    );
    expect(
      content,
      contains('json.optJSONObject(resolvedKey) ?: org.json.JSONObject()'),
    );

    // The Glance tree keeps calling fromPreferences unchanged.
    expect(
      content,
      contains('val widgetData = TimedWidgetData.fromPreferences(prefs)'),
    );
    expect(content, contains('Text(text = widgetData.label ?: "")'));
  });

  test('generates Kotlin widget with timed JSON data classes', () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'TimedJsonWidget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.timedjson'),
      ),
      className: 'TimedJsonWidget',
      dataFields: const [
        HWTimedData(HWJson('weather', HWJson('wind', HWString('direction')))),
      ],
      widgetTree: const HWText(
        HWTimedData(HWJson('weather', HWJson('wind', HWString('direction')))),
      ),
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/timedjson/TimedJsonWidgetHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(
      content,
      contains('val weather: TimedJsonWidgetWeatherJsonData? = null,'),
    );
    expect(
      content,
      contains(
        'weather = TimedJsonWidgetWeatherJsonData.fromJson(timedValues.optJSONObject("weather")),',
      ),
    );
    // Nested classes are emitted even though timed groups are absent from
    // jsonDataGroups.
    expect(content, contains('data class TimedJsonWidgetWeatherJsonData('));
    expect(content, contains('data class TimedJsonWidgetWeatherJsonDataWind('));
    expect(
      content,
      contains(
        'TimedJsonWidgetWeatherJsonDataWind.fromJson(json.optJSONObject("wind"))',
      ),
    );
    // Every timed emission is fully qualified, so a timed-only spec needs
    // neither import.
    expect(content, isNot(contains('import org.json.JSONObject')));
    expect(content, isNot(contains('import java.io.File')));
    expect(
      content,
      contains('Text(text = widgetData.weather?.wind?.direction ?: "")'),
    );
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
        android: HomeWidgetAndroidConfiguration(packageName: 'com.timedl10n'),
        localization: HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'TimedLocalized',
      dataFields: const [HWTimedData(greeting)],
      widgetTree: tree,
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/timedl10n/'
        'TimedLocalizedHomeWidget.kt',
      ),
    ).readAsStringSync();

    // The locale list and the resolution time compose into one signature...
    expect(
      content,
      contains(
        'fun fromPreferences(prefs: android.content.SharedPreferences, '
        'locales: List<String>, now: Long = System.currentTimeMillis()): '
        'TimedLocalizedData {',
      ),
    );
    // ...which the Glance body has to call with the locales it collected.
    expect(content, contains('val hwLocales = hwCurrentLocales(context)'));
    expect(
      content,
      contains(
        'val widgetData = TimedLocalizedData.fromPreferences(prefs, hwLocales)',
      ),
    );

    // The compiled translations travel to the reader, which merges the stored
    // map over them before resolving once.
    expect(
      content,
      contains(
        'greeting = hwReadTimedLocalized(timedValues, "greeting", locales, '
        'mapOf("en" to "Hello", "de" to "Hallo"), "en"),',
      ),
    );
    expect(
      content,
      contains('val merged = values.toMutableMap()'),
    );
    expect(
      content,
      contains(
        'timedValues.optJSONObject(key)?.let '
        '{ merged.putAll(hwLocalizedEntries(it)) }',
      ),
    );
    expect(content, contains('return hwLocalize(locales, merged, baseLocale)'));

    // Resolution itself is the untimed one, not a second implementation.
    expect(content, contains('private fun hwResolveLocalized('));
    expect('private fun hwResolveLocalized('.allMatches(content).length, 1);
    expect(
      content,
      contains('): String = hwResolveLocalized(locales, values, baseLocale) '
          '?: ""'),
    );
    // Nothing reads the field's own preferences key.
    expect(content, isNot(contains('private fun hwReadLocalized(')));
    expect(content, isNot(contains(r'${PREFERENCES_PREFIX}.greeting')));
  });

  test('resolves a localized leaf of a timed JSON group', () async {
    const summary = HWLocalizedString(
      'summary',
      defaultTranslations: {'en': 'Sunny', 'de': 'Sonnig'},
    );
    const tree = HWText(HWTimedData(HWJson('weather', summary)));
    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'TimedLeaf',
        widget: tree,
        android: HomeWidgetAndroidConfiguration(packageName: 'com.timedleaf'),
        localization: HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'TimedLeaf',
      dataFields: const [HWTimedData(HWJson('weather', summary))],
      widgetTree: tree,
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/timedleaf/TimedLeafHomeWidget.kt',
      ),
    ).readAsStringSync();

    // Same shape as an untimed leaf: the stored JSON wins, and the compiled
    // translations are the fallback when the path resolves to nothing.
    expect(
      content,
      contains(
        'text = (widgetData.weather?.summary ?: hwResolveLocalized(hwLocales, '
        'mapOf("en" to "Sunny", "de" to "Sonnig"), "en") ?: "Sunny")',
      ),
    );
    expect(content, contains('val hwLocales = hwCurrentLocales(context)'));
    expect(content, contains('private fun hwResolveLocalized('));
    // A leaf carries no stored translation map of its own, so no reader and no
    // locale parameter.
    expect(content, isNot(contains('hwReadTimedLocalized')));
    expect(content, isNot(contains('private fun hwLocalize(')));
    expect(
      content,
      contains(
        'fun fromPreferences(prefs: android.content.SharedPreferences, '
        'now: Long = System.currentTimeMillis()): TimedLeafData {',
      ),
    );
  });

  test('composes the locales and now parameters for a mixed spec', () async {
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
        android: HomeWidgetAndroidConfiguration(packageName: 'com.mixed'),
        localization: HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'Mixed',
      dataFields: const [greeting, HWTimedData(HWInt('temperature'))],
      widgetTree: tree,
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/mixed/MixedHomeWidget.kt',
      ),
    ).readAsStringSync();

    // Declaration and call site have to agree, or the Kotlin does not compile.
    expect(
      content,
      contains(
        'fun fromPreferences(prefs: android.content.SharedPreferences, '
        'locales: List<String>, now: Long = System.currentTimeMillis()): '
        'MixedData {',
      ),
    );
    expect(
      content,
      contains('val widgetData = MixedData.fromPreferences(prefs, hwLocales)'),
    );
    expect(content, contains('private fun hwReadLocalized('));
    expect(content, isNot(contains('hwReadTimedLocalized')));
  });

  test('keeps fromPreferences unchanged for specs without timed fields',
      () async {
    final spec = WidgetSpec(
      data: HomeWidget(
        name: 'NoTimed',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.notimed'),
      ),
      className: 'NoTimed',
      dataFields: const [
        HWInt('count'),
        HWJson('fileKey', HWString('title')),
      ],
    );

    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();

    final content = File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/notimed/NoTimedHomeWidget.kt',
      ),
    ).readAsStringSync();

    expect(
      content,
      contains(
        'fun fromPreferences(prefs: android.content.SharedPreferences): NoTimedData {',
      ),
    );
    expect(content, isNot(contains('resolveTimedValues')));
    expect(content, isNot(contains('timedData')));
    expect(content, isNot(contains('System.currentTimeMillis()')));
  });

  test('generates provider info XML and string resources with v2 fields',
      () async {
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
        'android:description="@string/home_widget_v2_widget_description"',
      ),
    );

    // Check Strings
    final stringsFile = File(
      p.join(
        tempDir.path,
        'android/app/src/main/res/values/home_widget_v2_widget.xml',
      ),
    );
    expect(stringsFile.existsSync(), isTrue);
    final stringsContent = stringsFile.readAsStringSync();
    expect(
      stringsContent,
      contains('name="home_widget_v2_widget_description"'),
    );
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
        'Box(modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground).padding(16.dp).fillMaxSize().clickable(onClick = actionStartActivity<MainActivity>()), contentAlignment = Alignment.Center) {',
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
        'Box(modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground).padding(16.dp).fillMaxSize().clickable(onClick = actionStartActivity<MainActivity>()), contentAlignment = Alignment.Center) {',
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
        'Box(modifier = GlanceModifier.background(ColorProvider(day = Color(0xFFFF0000), night = Color(0xFFFF0000))).padding(16.dp).fillMaxSize().clickable(onClick = actionStartActivity<MainActivity>()), contentAlignment = Alignment.Center) {',
      ),
    );
    expect(content, contains('if (widgetData.flag != null) {'));
  });

  group('widget URL', () {
    Future<String> generateFor(WidgetSpec spec, String packagePath) async {
      await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();
      final widgetFile = File(
        p.join(
          tempDir.path,
          'android/app/src/main/kotlin/$packagePath/'
          '${spec.className}HomeWidget.kt',
        ),
      );
      expect(widgetFile.existsSync(), isTrue);
      return widgetFile.readAsStringSync();
    }

    void writeManifest({String activityName = '.MainActivity'}) {
      final dir = Directory(
        p.join(tempDir.path, 'android', 'app', 'src', 'main'),
      )..createSync(recursive: true);
      File(p.join(dir.path, 'AndroidManifest.xml')).writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.urls">
    <application android:label="test">
        <activity android:name="$activityName" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''');
    }

    test('opens the app without a launch intent when no URL is configured',
        () async {
      final content = await generateFor(
        WidgetSpec(
          data: HomeWidget(
            name: 'Plain',
            android: HomeWidgetAndroidConfiguration(packageName: 'com.urls'),
          ),
          className: 'Plain',
        ),
        'com/urls',
      );

      expect(
        content,
        contains('clickable(onClick = actionStartActivity<MainActivity>())'),
      );
      expect(
        content,
        contains('import androidx.glance.action.actionStartActivity'),
      );
      expect(content, contains('import androidx.glance.action.clickable'));
      expect(
        content,
        isNot(contains('import es.antonborri.home_widget.actionStartActivity')),
      );
      expect(content, isNot(contains('Uri.parse')));
    });

    test('opens the app with the configured URL', () async {
      writeManifest();
      final content = await generateFor(
        WidgetSpec(
          data: HomeWidget(
            name: 'Linked',
            widgetUrl: 'myapp://linked',
            android: HomeWidgetAndroidConfiguration(packageName: 'com.urls'),
          ),
          className: 'Linked',
        ),
        'com/urls',
      );

      expect(
        content,
        contains(
          'clickable(onClick = actionStartActivity<MainActivity>(context, '
          'Uri.parse("myapp://linked?homeWidget")))',
        ),
      );
      expect(
        content,
        contains('import es.antonborri.home_widget.actionStartActivity'),
      );
      expect(content, contains('import android.net.Uri'));
      expect(
        content,
        isNot(
          contains(
            'import androidx.glance.action.actionStartActivity',
          ),
        ),
      );
    });

    test('prefers the Android URL over the top-level one', () async {
      writeManifest();
      final content = await generateFor(
        WidgetSpec(
          data: HomeWidget(
            name: 'Override',
            widgetUrl: 'myapp://shared',
            android: HomeWidgetAndroidConfiguration(
              packageName: 'com.urls',
              widgetUrl: 'myapp://android',
            ),
          ),
          className: 'Override',
        ),
        'com/urls',
      );

      expect(content, contains('Uri.parse("myapp://android?homeWidget")'));
      expect(content, isNot(contains('myapp://shared')));
    });

    test('imports the launcher activity when it lives in another package',
        () async {
      writeManifest(activityName: 'com.other.HostActivity');
      final content = await generateFor(
        WidgetSpec(
          data: HomeWidget(
            name: 'Foreign',
            widgetUrl: 'myapp://foreign',
            android: HomeWidgetAndroidConfiguration(packageName: 'com.urls'),
          ),
          className: 'Foreign',
        ),
        'com/urls',
      );

      expect(content, contains('import com.other.HostActivity'));
      expect(content, contains('actionStartActivity<HostActivity>(context'));
    });

    test('wires the launch intent-filter only when a URL is configured',
        () async {
      writeManifest();
      final manifest = File(
        p.join(
          tempDir.path,
          'android',
          'app',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      );

      await AndroidGenerator(
        spec: WidgetSpec(
          data: HomeWidget(
            name: 'Plain',
            android: HomeWidgetAndroidConfiguration(packageName: 'com.urls'),
          ),
          className: 'Plain',
        ),
        projectRoot: tempDir,
      ).generate();
      expect(
        manifest.readAsStringSync(),
        isNot(contains('es.antonborri.home_widget.action.LAUNCH')),
      );

      await AndroidGenerator(
        spec: WidgetSpec(
          data: HomeWidget(
            name: 'Linked',
            widgetUrl: 'myapp://linked',
            android: HomeWidgetAndroidConfiguration(packageName: 'com.urls'),
          ),
          className: 'Linked',
        ),
        projectRoot: tempDir,
      ).generate();
      expect(
        manifest.readAsStringSync(),
        contains(
          '<action android:name="es.antonborri.home_widget.action.LAUNCH" />',
        ),
      );
    });
  });
}
