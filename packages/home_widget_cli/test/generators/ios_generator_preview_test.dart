import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ios_preview_test');
    Directory(p.join(tempDir.path, 'ios')).createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<String> generate(WidgetSpec spec) async {
    await IosGenerator(spec: spec, projectRoot: tempDir).generate();
    return File(
      p.join(tempDir.path, 'ios/${spec.className}HomeWidget/Widget.swift'),
    ).readAsStringSync();
  }

  WidgetSpec specOf({
    required List<HWDataType<dynamic>> dataFields,
    bool? useLiveDataInPreview,
    HWWidget? widget,
  }) =>
      WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          useLiveDataInPreview: useLiveDataInPreview ?? true,
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example'),
          widget: widget,
        ),
        className: 'ExampleWidget',
        dataFields: dataFields,
      );

  const prefsExpr =
      'UserDefaults(suiteName: ExampleWidgetHomeWidgetFlavor.appGroupId)';

  group('getSnapshot', () {
    test('reads live defaults through the preview factory in a preview',
        () async {
      final content = await generate(
        specOf(dataFields: [HWString('label', previewValue: 'Sample')]),
      );

      expect(
        content,
        contains('''
    if context.isPreview {
      let prefs: UserDefaults? = $prefsExpr
      let data = ExampleWidgetData.previewFromUserDefaults(prefs)
      completion(ExampleWidgetHomeWidgetEntry(date: Date(), data: data))
      return
    }
'''),
      );
    });

    test('keeps stored data out of the preview when live data is off',
        () async {
      final content = await generate(
        specOf(
          dataFields: [HWString('label', previewValue: 'Sample')],
          useLiveDataInPreview: false,
        ),
      );

      expect(content, contains('      let prefs: UserDefaults? = nil\n'));
      expect(
        content,
        contains('      let data = ExampleWidgetData.previewFromUserDefaults'
            '(prefs)\n'),
      );
    });

    test('lets the iOS configuration override the top-level preview source',
        () async {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'ExampleWidget',
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.com.example',
            useLiveDataInPreview: false,
          ),
        ),
        className: 'ExampleWidget',
        dataFields: const [HWString('label')],
      );
      final content = await generate(spec);

      // Without preview values the widget's own factory still serves, just
      // never reaching the stored data.
      expect(content, contains('      let prefs: UserDefaults? = nil\n'));
      expect(
        content,
        contains(
          '      let data = ExampleWidgetData.fromUserDefaults(prefs)\n',
        ),
      );
      expect(content, isNot(contains('previewFromUserDefaults')));
    });

    test('branches on the loaded timed entries of the preview prefs', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized('title', defaultTranslations: {'en': 'Hi'}),
            HWTimedData(HWInt('count', previewValue: 42)),
          ],
          useLiveDataInPreview: false,
        ),
      );

      expect(
        content,
        contains('''
    if context.isPreview {
      let prefs: UserDefaults? = nil
      let timedEntries = ExampleWidgetData.loadTimedEntries(prefs)
      let data = ExampleWidgetData.previewFromUserDefaults(prefs, timedEntries: timedEntries)

      completion(ExampleWidgetHomeWidgetEntry(date: Date(), data: data, timedEntries: timedEntries, preview: true))
      return
    }
'''),
      );
    });

    test('emits no branch when a preview reads exactly what the widget reads',
        () async {
      final content = await generate(
        specOf(dataFields: const [HWString('label', defaultValue: 'Hi')]),
      );

      expect(content, isNot(contains('context.isPreview')));
      expect(content, isNot(contains('previewFromUserDefaults')));
    });

    test('keeps the non-preview branch reading the widget defaults', () async {
      final content = await generate(
        specOf(dataFields: [HWString('label', previewValue: 'Sample')]),
      );

      expect(
        content,
        contains('''
    let prefs = $prefsExpr
    let data = ExampleWidgetData.fromUserDefaults(prefs)

    completion(ExampleWidgetHomeWidgetEntry(date: Date(), data: data))
'''),
      );
    });
  });

  group('placeholder', () {
    test('builds the redacted entry from the preview factory', () async {
      final content = await generate(
        specOf(dataFields: [HWString('label', previewValue: 'Sample')]),
      );

      expect(
        content,
        contains(
          '    ExampleWidgetHomeWidgetEntry(date: Date(), data: '
          'ExampleWidgetData.previewFromUserDefaults(nil))\n',
        ),
      );
    });

    test('marks the entry as a preview where the view re-reads', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized(
              'title',
              defaultTranslations: {'en': 'Hi'},
              previewTranslations: {'en': 'Sample'},
            ),
          ],
        ),
      );

      expect(
        content,
        contains(
          '    ExampleWidgetHomeWidgetEntry(date: Date(), data: '
          'ExampleWidgetData.previewFromUserDefaults(nil), preview: true)\n',
        ),
      );
    });

    test('stays on the widget factory without preview values', () async {
      final content = await generate(
        specOf(dataFields: const [HWString('label')]),
      );

      expect(
        content,
        contains(
          '    ExampleWidgetHomeWidgetEntry(date: Date(), data: '
          'ExampleWidgetData.fromUserDefaults(nil))\n',
        ),
      );
    });
  });

  group('preview factory', () {
    test('falls back on the preview value of every primitive', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWInt('count', defaultValue: 1, previewValue: 42),
            HWString('label', previewValue: 'Sample'),
            HWDouble('ratio', previewValue: 0.5),
            HWBool('flag', previewValue: true),
          ],
        ),
      );

      expect(
        content,
        contains('''
  static func previewFromUserDefaults(_ defaults: UserDefaults?) -> ExampleWidgetData {
    return ExampleWidgetData(
      count: (defaults?.object(forKey: "\\(paramPrefix).count") as? Int ?? 42),
      label: (defaults?.string(forKey: "\\(paramPrefix).label") ?? "Sample"),
      ratio: (defaults?.object(forKey: "\\(paramPrefix).ratio") as? Double ?? 0.5),
      flag: (defaults?.object(forKey: "\\(paramPrefix).flag") as? Bool ?? true),
    )
  }
'''),
      );
    });

    test('leaves fromUserDefaults on the shipped defaults', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWInt('count', defaultValue: 1, previewValue: 42),
            HWString('label', previewValue: 'Sample'),
          ],
        ),
      );

      expect(
        content,
        contains('''
  static func fromUserDefaults(_ defaults: UserDefaults?) -> ExampleWidgetData {
    return ExampleWidgetData(
      count: (defaults?.object(forKey: "\\(paramPrefix).count") as? Int ?? 1),
      label: defaults?.string(forKey: "\\(paramPrefix).label"),
    )
  }
'''),
      );
    });

    test('parses the preview instant of a date out of its ISO spelling',
        () async {
      final content = await generate(
        specOf(
          dataFields: const [
            HWDateTime('due', previewValue: '2024-03-01T10:00:00Z'),
          ],
        ),
      );

      expect(
        content,
        contains(
          '      due: hwParseIsoDate(defaults?.string('
          'forKey: "\\(paramPrefix).due") ?? "2024-03-01T10:00:00Z"),\n',
        ),
      );
      expect(
        content,
        contains(
          '      due: hwParseIsoDate(defaults?.string('
          'forKey: "\\(paramPrefix).due") ?? ""),\n',
        ),
      );
    });

    test('resolves a preview image to its bundled asset path', () async {
      final content = await generate(
        specOf(
          dataFields: const [HWImageData('photo', previewAsset: 'a/logo.png')],
        ),
      );

      expect(
        content,
        contains(
          '      photo: (defaults?.string(forKey: "\\(paramPrefix).photo") '
          '?? flutterAssetPath("a/logo.png")),\n',
        ),
      );
    });

    test('resolves a localized string against its preview translations',
        () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized(
              'title',
              defaultTranslations: {'en': 'Hi', 'de': 'Hallo'},
              previewTranslations: {'en': 'Sample', 'de': 'Beispiel'},
            ),
          ],
        ),
      );

      expect(
        content,
        contains(
          '      title: hwReadLocalized(defaults, "\\(paramPrefix).title", '
          '["en": "Sample", "de": "Beispiel"], baseLocale: "en"),\n',
        ),
      );
      expect(
        content,
        contains(
          '      title: hwReadLocalized(defaults, "\\(paramPrefix).title", '
          '["en": "Hi", "de": "Hallo"], baseLocale: "en"),\n',
        ),
      );
    });

    test('reads a timed field out of the same active entry', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWTimedData(HWInt('count', defaultValue: 1, previewValue: 42)),
          ],
        ),
      );

      expect(
        content,
        contains('      count: (timedValues["count"] as? Int) ?? 42,\n'),
      );
      expect(
        content,
        contains('      count: (timedValues["count"] as? Int) ?? 1,\n'),
      );
      expect(
        content,
        contains('''
  static func previewFromUserDefaults(
    _ defaults: UserDefaults?,
    at date: Date = Date(),
    timedEntries: [(date: Date, values: [String: Any])]? = nil
  ) -> ExampleWidgetData {
'''),
      );
    });

    test('emits no twin when nothing ships a preview value', () async {
      final content = await generate(
        specOf(
          dataFields: const [
            HWInt('count', defaultValue: 1),
            HWJson('stats', HWString('city', defaultValue: 'Berlin')),
          ],
        ),
      );

      expect(content, isNot(contains('previewFrom')));
    });
  });

  group('preview JSON factories', () {
    test('materializes the root node an unreadable path leaves absent',
        () async {
      final content = await generate(
        specOf(
          dataFields: const [
            HWJson('stats', HWInt('hits', previewValue: 7)),
          ],
        ),
      );

      expect(
        content,
        contains('''
  static func previewFromPath(_ path: String?) -> ExampleWidgetStatsJsonData? {
    guard let path else { return previewFromJson([:]) }
    guard FileManager.default.fileExists(atPath: path) else { return previewFromJson([:]) }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return previewFromJson([:]) }
      return previewFromJson(json)
    } catch {
      return previewFromJson([:])
    }
  }
'''),
      );
      expect(
        content,
        contains('''
  static func previewFromJson(_ json: [String: Any]?) -> ExampleWidgetStatsJsonData? {
    let values = json ?? [:]
    return ExampleWidgetStatsJsonData(
      hits: (values["hits"] as? Int) ?? 7,
    )
  }
'''),
      );
    });

    test('leaves the shipped root factory giving up on an absent group',
        () async {
      final content = await generate(
        specOf(
          dataFields: const [
            HWJson('stats', HWInt('hits', previewValue: 7)),
          ],
        ),
      );

      expect(
        content,
        contains('''
  static func fromPath(_ path: String?) -> ExampleWidgetStatsJsonData? {
    guard let path else { return nil }
'''),
      );
      expect(
        content,
        contains('''
  static func fromJson(_ json: [String: Any]?) -> ExampleWidgetStatsJsonData? {
    guard let values = json else { return nil }
    return ExampleWidgetStatsJsonData(
      hits: values["hits"] as? Int,
    )
  }
'''),
      );
    });

    test('descends into a nested node through the preview twin', () async {
      final content = await generate(
        specOf(
          dataFields: const [
            HWJson('stats', HWJson('inner', HWInt('hits', previewValue: 7))),
          ],
        ),
      );

      expect(
        content,
        contains(
          '      inner: ExampleWidgetStatsJsonDataInner.previewFromJson('
          'values["inner"] as? [String: Any]),\n',
        ),
      );
      expect(
        content,
        contains(
          '      inner: ExampleWidgetStatsJsonDataInner.fromJson('
          'values["inner"] as? [String: Any]),\n',
        ),
      );
    });

    test('reaches the preview value of a date leaf', () async {
      final content = await generate(
        specOf(
          dataFields: const [
            HWJson(
              'stats',
              HWDateTime('due', previewValue: '2024-03-01T10:00:00Z'),
            ),
          ],
        ),
      );

      expect(
        content,
        contains(
          '      due: hwParseIsoDate((values["due"] as? String) '
          '?? "2024-03-01T10:00:00Z"),\n',
        ),
      );
    });
  });

  group('file helpers', () {
    test('emits the asset resolver for a preview asset alone', () async {
      final content = await generate(
        specOf(
          dataFields: const [HWImageData('photo', previewAsset: 'a/logo.png')],
        ),
      );

      expect(
        content,
        contains('private func flutterAssetPath(_ asset: String)'),
      );
    });

    test('emits no asset resolver without any asset', () async {
      final content = await generate(
        specOf(dataFields: const [HWImageData('photo')]),
      );

      expect(content, isNot(contains('private func flutterAssetPath')));
    });
  });

  group('render-time re-resolve', () {
    test('re-reads a preview entry through the preview factory', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized(
              'title',
              defaultTranslations: {'en': 'Hi'},
              previewTranslations: {'en': 'Sample'},
            ),
          ],
          useLiveDataInPreview: false,
        ),
      );

      expect(content, contains('  var preview: Bool = false\n'));
      expect(
        content,
        contains('''
    let prefs: UserDefaults? = entry.preview ? nil : $prefsExpr
    let data = entry.preview
      ? ExampleWidgetData.previewFromUserDefaults(prefs)
      : ExampleWidgetData.fromUserDefaults(prefs)
'''),
      );
    });

    test('keeps the live prefs and only switches factory', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized(
              'title',
              defaultTranslations: {'en': 'Hi'},
              previewTranslations: {'en': 'Sample'},
            ),
          ],
        ),
      );

      expect(
        content,
        contains('''
    let prefs = $prefsExpr
    let data = entry.preview
      ? ExampleWidgetData.previewFromUserDefaults(prefs)
      : ExampleWidgetData.fromUserDefaults(prefs)
'''),
      );
    });

    test('re-reads at the entry date once timed fields exist', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized('title', defaultTranslations: {'en': 'Hi'}),
            HWTimedData(HWInt('count', previewValue: 42)),
          ],
        ),
      );

      expect(
        content,
        contains('''
    let data = entry.preview
      ? ExampleWidgetData.previewFromUserDefaults(prefs, at: entry.date, timedEntries: entry.timedEntries)
      : ExampleWidgetData.fromUserDefaults(prefs, at: entry.date, timedEntries: entry.timedEntries)
'''),
      );
    });

    test('carries no preview flag when the entry cannot differ', () async {
      final content = await generate(
        specOf(
          dataFields: [
            HWString.localized('title', defaultTranslations: {'en': 'Hi'}),
          ],
        ),
      );

      expect(content, isNot(contains('var preview: Bool')));
      expect(
        content,
        contains('''
    let prefs = $prefsExpr
    let data = ExampleWidgetData.fromUserDefaults(prefs)
'''),
      );
    });
  });
}
