import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

const _localization = HomeWidgetLocalization(
  defaultLocale: 'en',
  supportedLocales: ['en', 'de'],
);

WidgetSpec _spec({
  required HWWidget widget,
  List<HWDataType<dynamic>>? dataFields,
  bool useLiveDataInPreview = true,
  bool autoUpdatePreview = true,
  HomeWidgetLocalization? localization,
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Preview',
        widget: widget,
        android: HomeWidgetAndroidConfiguration(
          packageName: 'com.preview',
          autoUpdatePreview: autoUpdatePreview,
        ),
        localization: localization,
        useLiveDataInPreview: useLiveDataInPreview,
      ),
      className: 'Preview',
      dataFields: dataFields ?? widget.dataDependencies.toList(),
      widgetTree: widget,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    final mockLogger = _MockLogger();
    logger = mockLogger;
    when(() => mockLogger.success(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);

    tempDir = Directory.systemTemp.createTempSync('android_preview_test');
    Directory(p.join(tempDir.path, 'android', 'app'))
        .createSync(recursive: true);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<String> generate(WidgetSpec spec) async {
    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();
    return File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/preview/PreviewHomeWidget.kt',
      ),
    ).readAsStringSync();
  }

  Future<String> generateReceiver(WidgetSpec spec) async {
    await AndroidGenerator(spec: spec, projectRoot: tempDir).generate();
    return File(
      p.join(
        tempDir.path,
        'android/app/src/main/kotlin/com/preview/PreviewHomeWidgetReceiver.kt',
      ),
    ).readAsStringSync();
  }

  group('providePreview', () {
    test('composes from the stored data when the preview uses live data',
        () async {
      final content = await generate(
        _spec(widget: const HWText.fixed('hello')),
      );

      expect(
        content,
        contains(
          '  override suspend fun providePreview(context: Context, '
          'widgetCategory: Int) {\n'
          '    provideContent { WidgetContent(context, '
          'HomeWidgetGlanceState(HomeWidgetPlugin.getData(context))) }\n'
          '  }',
        ),
      );
      expect(
        content,
        contains('import es.antonborri.home_widget.HomeWidgetPlugin'),
      );
    });

    test('composes from an empty store when the preview must not read data',
        () async {
      final content = await generate(
        _spec(
          widget: const HWText.fixed('hello'),
          useLiveDataInPreview: false,
        ),
      );

      expect(
        content,
        contains(
          'WidgetContent(context, '
          'HomeWidgetGlanceState(HomeWidgetPreviews.emptyPreferences))',
        ),
      );
      expect(
        content,
        contains('import es.antonborri.home_widget.HomeWidgetPreviews'),
      );
      expect(content, isNot(contains('HomeWidgetPlugin.getData')));
    });

    test('WidgetContent takes the preview flag where twins exist', () async {
      final content = await generate(
        _spec(widget: const HWText(HWString('greeting', previewValue: 'Hi'))),
      );

      expect(
        content,
        contains(
          '  private fun WidgetContent(context: Context, '
          'currentState: HomeWidgetGlanceState, preview: Boolean = false) {',
        ),
      );
      expect(
        content,
        contains(
          'WidgetContent(context, '
          'HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)), '
          'preview = true)',
        ),
      );
      // The widget's own path never asks for the preview.
      expect(
        content,
        contains('provideContent { WidgetContent(context, currentState()) }'),
      );
    });

    test('WidgetContent keeps its plain shape without preview values',
        () async {
      final content = await generate(
        _spec(widget: const HWText(HWString('greeting'))),
      );

      expect(
        content,
        contains(
          '  private fun WidgetContent(context: Context, '
          'currentState: HomeWidgetGlanceState) {',
        ),
      );
      expect(content, isNot(contains('preview: Boolean')));
      expect(content, isNot(contains('preview = true')));
    });

    test('reads through the preview factory only when one exists', () async {
      final withPreview = await generate(
        _spec(
          widget: const HWText(HWString('greeting', previewValue: 'Hi there')),
        ),
      );
      expect(
        withPreview,
        contains(
          '    val widgetData =\n'
          '        if (preview) PreviewData.previewFromPreferences(prefs)\n'
          '        else PreviewData.fromPreferences(prefs)',
        ),
      );

      final withoutPreview = await generate(
        _spec(widget: const HWText(HWString('greeting'))),
      );
      expect(
        withoutPreview,
        contains('    val widgetData = PreviewData.fromPreferences(prefs)'),
      );
      expect(withoutPreview, isNot(contains('previewFromPreferences')));
    });
  });

  group('preview data factories', () {
    test('a string falls back on its preview value, the widget on its default',
        () async {
      final content = await generate(
        _spec(
          widget: const HWText(
            HWString('greeting', defaultValue: 'Hello', previewValue: 'Hi'),
          ),
        ),
      );

      expect(
        content,
        contains(
          '        fun fromPreferences(prefs: android.content.SharedPreferences)'
          ': PreviewData {\n'
          '            return PreviewData(\n'
          '                greeting = prefs.getString('
          '"\${PREFERENCES_PREFIX}.greeting", "Hello"),\n'
          '            )\n'
          '        }',
        ),
      );
      expect(
        content,
        contains(
          '        fun previewFromPreferences('
          'prefs: android.content.SharedPreferences): PreviewData {\n'
          '            return PreviewData(\n'
          '                greeting = prefs.getString('
          '"\${PREFERENCES_PREFIX}.greeting", "Hi"),\n'
          '            )\n'
          '        }',
        ),
      );
    });

    test('a preview value on one field twins every other read too', () async {
      final content = await generate(
        _spec(
          widget: const HWColumn(
            children: [
              HWText(HWString('greeting', previewValue: 'Hi')),
              HWText(HWInt('count', defaultValue: 1)),
            ],
          ),
        ),
      );

      expect(
        content,
        contains(
          '                count = if (prefs.contains('
          '"\${PREFERENCES_PREFIX}.count")) '
          '(try { prefs.getInt("\${PREFERENCES_PREFIX}.count", 0).toLong() } '
          'catch (_: ClassCastException) { '
          'prefs.getLong("\${PREFERENCES_PREFIX}.count", 0L) }) else 1L,',
        ),
      );
      // Twice: the shipped default is what the preview falls back on as well.
      expect(
        'else 1L,'.allMatches(content).length,
        2,
      );
    });

    test('an int previews with its own sample value', () async {
      final content = await generate(
        _spec(
          widget: const HWText(
            HWInt('count', defaultValue: 1, previewValue: 42),
          ),
        ),
      );

      expect(content, contains('else 1L,'));
      expect(content, contains('else 42L,'));
    });

    test('a date parses its preview instant out of an ISO fallback', () async {
      final content = await generate(
        _spec(
          widget: const HWText.dateTime(
            HWDateTime('due', previewValue: '2024-03-01T10:00:00Z'),
          ),
        ),
      );

      expect(
        content,
        contains(
          '                due = hwParseIsoDate('
          'prefs.getString("\${PREFERENCES_PREFIX}.due", null) ?: ""),',
        ),
      );
      expect(
        content,
        contains(
          '                due = hwParseIsoDate('
          'prefs.getString("\${PREFERENCES_PREFIX}.due", null) '
          '?: "2024-03-01T10:00:00Z"),',
        ),
      );
    });

    test('a runtime image previews through its asset key', () async {
      final content = await generate(
        _spec(
          widget: const HWImage(
            HWImageData('avatar', previewAsset: 'assets/logo.png'),
          ),
        ),
      );

      expect(
        content,
        contains(
          '                avatar = prefs.getString('
          '"\${PREFERENCES_PREFIX}.avatar", null),',
        ),
      );
      expect(
        content,
        contains(
          '                avatar = prefs.getString('
          '"\${PREFERENCES_PREFIX}.avatar", "assets/logo.png"),',
        ),
      );
      // The decoder reads anything that is not an absolute path out of the
      // APK's assets, so the preview key renders through the same call.
      expect(content, contains('private fun hwDecodeImage('));
      expect(content, contains(r'context.assets.open("flutter_assets/$path")'));
    });

    test('a localized string previews with its own translations', () async {
      final content = await generate(
        _spec(
          // ignore: invalid_use_of_internal_member
          widget: HWText(
            // ignore: invalid_use_of_internal_member
            HWLocalizedString.resolved(
              'greeting',
              defaultTranslations: const {'en': 'Hello', 'de': 'Hallo'},
              previewTranslations: const {'en': 'Hi there', 'de': 'Hi da'},
              isConstant: false,
              defaultLocale: 'en',
              resourcePrefix: 'home_widget_preview',
            ),
          ),
          localization: _localization,
        ),
      );

      expect(
        content,
        contains(
          'hwReadLocalized(prefs, "\${PREFERENCES_PREFIX}.greeting", locales, '
          'mapOf("en" to "Hello", "de" to "Hallo"), "en")',
        ),
      );
      expect(
        content,
        contains(
          'hwReadLocalized(prefs, "\${PREFERENCES_PREFIX}.greeting", locales, '
          'mapOf("en" to "Hi there", "de" to "Hi da"), "en")',
        ),
      );
      // Both factories take the resolved locales the same way.
      expect(
        content,
        contains(
          'fun previewFromPreferences(prefs: android.content.SharedPreferences, '
          'locales: List<String>): PreviewData {',
        ),
      );
    });

    test('a JSON root materializes an absent group in the preview', () async {
      final content = await generate(
        _spec(
          widget: const HWText(
            HWJson('contact', HWString('name', previewValue: 'Ada')),
          ),
        ),
      );

      // The widget itself still renders nothing for a group that was never
      // saved...
      expect(
        content,
        contains(
          '        fun fromPath(path: String?): PreviewContactJsonData? {\n'
          '            if (path == null) return null\n',
        ),
      );
      expect(
        content,
        contains(
          '        fun fromJson(obj: org.json.JSONObject?): '
          'PreviewContactJsonData? {\n'
          '            if (obj == null) return null\n'
          '            val json = obj\n',
        ),
      );
      // ...while the preview builds one out of thin air, so the leaf fallback
      // is reached before the app ever saved the group.
      expect(
        content,
        contains(
          '        fun previewFromPath(path: String?): '
          'PreviewContactJsonData? {\n'
          '            if (path == null) return previewFromJson('
          'org.json.JSONObject())\n'
          '            return try {\n'
          '                val file = java.io.File(path)\n'
          '                if (!file.exists()) return previewFromJson('
          'org.json.JSONObject())\n'
          '                previewFromJson(org.json.JSONObject('
          'file.readText()))\n'
          '            } catch (_: Exception) {\n'
          '                previewFromJson(org.json.JSONObject())\n'
          '            }\n'
          '        }',
        ),
      );
      expect(
        content,
        contains(
          '        fun previewFromJson(obj: org.json.JSONObject?): '
          'PreviewContactJsonData? {\n'
          '            val json = obj ?: org.json.JSONObject()\n'
          '            return PreviewContactJsonData(\n'
          '                name = if (json.has("name") && '
          '!json.isNull("name")) json.optString("name") else "Ada",\n'
          '            )\n'
          '        }',
        ),
      );
      expect(
        content,
        contains(
          '                contact = PreviewContactJsonData.previewFromPath('
          'prefs.getString("\${PREFERENCES_PREFIX}.contact", null)),',
        ),
      );
    });

    test('a nested JSON node gets a preview twin the root calls', () async {
      final content = await generate(
        _spec(
          widget: const HWText(
            HWJson(
              'contact',
              HWJson('profile', HWString('name', previewValue: 'Ada')),
            ),
          ),
        ),
      );

      expect(
        content,
        contains(
          '                profile = PreviewContactJsonDataProfile.'
          'previewFromJson(json.optJSONObject("profile")),',
        ),
      );
      expect(
        content,
        contains(
          '        fun previewFromJson(obj: org.json.JSONObject?): '
          'PreviewContactJsonDataProfile? {\n'
          '            val json = obj ?: org.json.JSONObject()\n',
        ),
      );
    });

    test('a localized JSON leaf previews its translations per locale',
        () async {
      final content = await generate(
        _spec(
          widget: const HWText(
            HWJson(
              'contact',
              HWString.localized(
                'name',
                defaultTranslations: {'en': 'Ada', 'de': 'Ada'},
                previewTranslations: {'en': 'Sample', 'de': 'Beispiel'},
              ),
            ),
          ),
          localization: _localization,
        ),
      );

      // The preview resolves the preview translations itself instead of
      // inlining the base locale's text...
      expect(
        content,
        contains(
          '                name = if (json.has("name") && '
          '!json.isNull("name")) json.optString("name") else '
          'hwResolveLocalized(locales, '
          'mapOf("en" to "Sample", "de" to "Beispiel"), "en"),',
        ),
      );
      // ...which is what the threaded locale list is for.
      expect(
        content,
        contains(
          '        fun previewFromJson(obj: org.json.JSONObject?, '
          'locales: List<String>): PreviewContactJsonData? {',
        ),
      );
      expect(
        content,
        contains(
          '        fun previewFromPath(path: String?, locales: List<String>): '
          'PreviewContactJsonData? {\n'
          '            if (path == null) return previewFromJson('
          'org.json.JSONObject(), locales)\n',
        ),
      );
      expect(
        content,
        contains(
          '                contact = PreviewContactJsonData.previewFromPath('
          'prefs.getString("\${PREFERENCES_PREFIX}.contact", null), locales),',
        ),
      );
      expect(
        content,
        contains(
          'fun previewFromPreferences(prefs: android.content.SharedPreferences, '
          'locales: List<String>): PreviewData {',
        ),
      );
      expect(
        content,
        contains('        if (preview) PreviewData.previewFromPreferences('
            'prefs, hwLocales)'),
      );
      // The plain read is untouched: no locale list, no resolution.
      expect(
        content,
        contains(
          '        fun fromJson(obj: org.json.JSONObject?): '
          'PreviewContactJsonData? {',
        ),
      );
      expect(
        content,
        contains(
          'fun fromPreferences(prefs: android.content.SharedPreferences): '
          'PreviewData {',
        ),
      );
    });

    test(
        'a localized JSON leaf without preview translations falls back to null',
        () async {
      final content = await generate(
        _spec(
          widget: const HWColumn(
            children: [
              HWText(
                HWJson(
                  'contact',
                  HWString.localized(
                    'name',
                    defaultTranslations: {'en': 'Ada', 'de': 'Ada'},
                  ),
                ),
              ),
              HWText(HWString('title', previewValue: 'Engineer')),
            ],
          ),
          localization: _localization,
        ),
      );

      // Null, not the base locale's text: the render site's own chain resolves
      // the shipped translations against the reader's locales.
      expect(
        content,
        contains(
          '                name = if (json.has("name") && '
          '!json.isNull("name")) json.optString("name") else null,',
        ),
      );
      expect(content, isNot(contains('else "Ada"')));
      // Nothing to resolve in the factory, so no locale list is threaded in.
      expect(
        content,
        contains(
          '        fun previewFromJson(obj: org.json.JSONObject?): '
          'PreviewContactJsonData? {',
        ),
      );
      expect(
        content,
        contains(
          'hwResolveLocalized(hwLocales, mapOf("en" to "Ada", "de" to "Ada"), '
          '"en")',
        ),
      );
    });

    test('a timed value previews out of the resolved entry', () async {
      final content = await generate(
        _spec(
          widget: const HWText(
            HWTimedData(HWString('slot', previewValue: 'Soon')),
          ),
        ),
      );

      expect(
        content,
        contains(
          '                slot = if (timedValues.has("slot") && '
          '!timedValues.isNull("slot")) timedValues.optString("slot") '
          'else null,',
        ),
      );
      expect(
        content,
        contains(
          '                slot = if (timedValues.has("slot") && '
          '!timedValues.isNull("slot")) timedValues.optString("slot") '
          'else "Soon",',
        ),
      );
      // Both factories take `now` and share the one resolver.
      expect(
        content,
        contains(
          'fun previewFromPreferences(prefs: android.content.SharedPreferences, '
          'now: Long = System.currentTimeMillis()): PreviewData {\n'
          '            val timedValues = resolveTimedValues(prefs, now)',
        ),
      );
      expect('private fun resolveTimedValues('.allMatches(content).length, 1);
    });

    test('no twins at all without a single preview value', () async {
      final content = await generate(
        _spec(
          widget: const HWText(HWJson('contact', HWString('name'))),
        ),
      );

      expect(content, isNot(contains('previewFromPreferences')));
      expect(content, isNot(contains('previewFromPath')));
      expect(content, isNot(contains('previewFromJson')));
      // ...but the gallery still renders, through the plain factories.
      expect(content, contains('override suspend fun providePreview('));
    });
  });

  group('previewFingerprint', () {
    test('covers the content hash, the locales and the live data', () async {
      final spec = _spec(
        widget: const HWText(HWString('greeting', previewValue: 'Hi')),
      );
      final content = await generate(spec);

      expect(
        content,
        contains(
          '  fun previewFingerprint(context: Context): String {\n'
          '    val hwLocales = hwCurrentLocales(context)\n'
          '    val hwPreviewData =\n'
          '        PreviewData.previewFromPreferences('
          'HomeWidgetPlugin.getData(context))\n'
          '    return listOf(\n'
          '      "${spec.previewContentHash}",\n'
          '      hwLocales.joinToString(","),\n'
          '      hwPreviewData.toString(),\n'
          '    ).joinToString("|")\n'
          '  }',
        ),
      );
      expect(
        content,
        contains(
          'private fun hwCurrentLocales(context: Context): List<String>',
        ),
      );
    });

    test('covers the mtime of every runtime image the preview reads', () async {
      final content = await generate(
        _spec(
          widget: const HWColumn(
            children: [
              HWImage.asset('assets/logo.png'),
              HWImage(HWImageData('picture')),
              HWImage(HWTimedData(HWImageData('slide'))),
              HWImage(HWJson('contact', HWImageData('avatar'))),
            ],
          ),
        ),
      );

      expect(
        content,
        contains(
          '      hwPreviewData.toString(),\n'
          '      listOf(hwPreviewData.picture, hwPreviewData.slide, '
          'hwPreviewData.contact?.avatar).joinToString(",") '
          '{ hwPath -> hwPath?.let { java.io.File(it).lastModified().toString() }'
          ' ?: "" },\n',
        ),
      );
    });

    test('an asset-only widget keeps the fingerprint file-free', () async {
      final content = await generate(
        _spec(
          widget: const HWColumn(
            children: [
              HWImage.asset('assets/logo.png'),
              HWText(HWString('greeting', previewValue: 'Hi')),
            ],
          ),
        ),
      );

      expect(
        content,
        contains(
          '      hwPreviewData.toString(),\n'
          '    ).joinToString("|")',
        ),
      );
      expect(content, isNot(contains('lastModified()')));
    });

    test('leaves out the data when the preview does not read it', () async {
      final content = await generate(
        _spec(
          widget: const HWText(HWString('greeting', previewValue: 'Hi')),
          useLiveDataInPreview: false,
        ),
      );

      expect(content, contains('fun previewFingerprint(context: Context)'));
      expect(content, isNot(contains('hwPreviewData')));
    });

    test('reads the locales through the resolver the widget already emits',
        () async {
      final content = await generate(
        _spec(
          // ignore: invalid_use_of_internal_member
          widget: HWText(
            // ignore: invalid_use_of_internal_member
            HWLocalizedString.resolved(
              'greeting',
              defaultTranslations: const {'en': 'Hello', 'de': 'Hallo'},
              isConstant: false,
              defaultLocale: 'en',
              resourcePrefix: 'home_widget_preview',
            ),
          ),
          localization: _localization,
        ),
      );

      expect(
        content,
        contains(
          '    val hwLocales = hwCurrentLocales(context)\n'
          '    val hwPreviewData =\n'
          '        PreviewData.fromPreferences('
          'HomeWidgetPlugin.getData(context), hwLocales)\n'
          '    return listOf(\n',
        ),
      );
      expect(content, contains('      hwLocales.joinToString(","),'));
      expect(
        content,
        isNot(contains('ConfigurationCompat.getLocales(context.resources')),
      );
    });

    test('shares the compat import with a widget that formats', () async {
      final content = await generate(
        _spec(widget: const HWText(HWInt('count'))),
      );

      expect(content, contains('      hwLocales.joinToString(","),'));
      expect(content, contains('private fun hwFormatLocale('));
      expect(
        'import androidx.core.os.ConfigurationCompat'
            .allMatches(content)
            .length,
        1,
      );
    });

    test('the receiver forwards the fingerprint', () async {
      final receiver = await generateReceiver(
        _spec(widget: const HWText.fixed('hello')),
      );

      expect(receiver, contains('import android.content.Context'));
      expect(
        receiver,
        contains(
          '  override fun previewFingerprint(context: Context): String =\n'
          '      glanceAppWidget.previewFingerprint(context)',
        ),
      );
    });

    test('autoUpdatePreview false emits neither side of it', () async {
      final spec = _spec(
        widget: const HWText.fixed('hello'),
        autoUpdatePreview: false,
      );
      final content = await generate(spec);
      final receiver = await generateReceiver(spec);

      expect(content, isNot(contains('previewFingerprint')));
      expect(receiver, isNot(contains('previewFingerprint')));
      expect(receiver, isNot(contains('import android.content.Context')));
      // The preview itself is still provided; only the automatic
      // re-registration is opted out of.
      expect(content, contains('override suspend fun providePreview('));
    });
  });
}
