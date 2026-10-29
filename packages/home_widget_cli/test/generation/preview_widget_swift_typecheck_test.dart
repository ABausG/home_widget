@Tags(['integration', 'integration_ios'])
library;

import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/util/font_resolver.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';
import '../helpers/mock_logger.dart';
import '../helpers/xcode_project.dart';

/// Whether the preview reads the widget's own stored data, which decides
/// whether the generated preview branch passes live defaults or `nil` — and,
/// with it, whether the entry has to carry which read it was built with.
const _liveDataInPreview = [true, false];

String? _unavailable() {
  try {
    final result = Process.runSync('xcrun', ['--find', 'swiftc']);
    if (result.exitCode != 0) return 'xcrun cannot find swiftc';
    return null;
  } on ProcessException {
    return 'xcrun is not available';
  }
}

/// Every shape a preview value can take, so the preview factories, their JSON
/// twins and the re-resolving entry view all have to compile.
WidgetSpec _fieldsSpec({required bool useLiveDataInPreview}) => WidgetSpec(
      data: HomeWidget(
        name: 'Weather',
        useLiveDataInPreview: useLiveDataInPreview,
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
      ),
      className: 'Weather',
      dataFields: [
        HWString('city', defaultValue: 'Berlin', previewValue: 'Cupertino'),
        HWInt('degrees', previewValue: 21),
        HWDouble('humidity', previewValue: 0.42),
        HWBool('raining', previewValue: true),
        HWDateTime('updated', previewValue: '2024-03-01T10:00:00Z'),
        HWImageData('icon', previewAsset: 'assets/sun.png'),
        HWString.localized(
          'headline',
          defaultTranslations: const {'en': 'Weather', 'de': 'Wetter'},
          previewTranslations: const {'en': 'Sunny', 'de': 'Sonnig'},
        ),
        const HWJson(
          'forecast',
          HWJson('today', HWString('summary', previewValue: 'Clear')),
        ),
        HWTimedData(HWInt('feelsLike', previewValue: 19)),
      ],
    );

const _condition = HWIconData.resolved(
  'condition',
  entries: [HWIconEntry('happy', 0xE88A), HWIconEntry('sad', 0xE25B)],
  iconFont: HWIconFont(family: 'BrandIcons', package: 'brand_icons'),
  defaultValue: 0xE88A,
);

/// Lists of every kind beside a root field: items varying by index, image
/// included, items repeating one sample, and an item reading no field at all.
const _lists = HWColumn(
  children: [
    HWText(HWString('city', previewValue: 'Berlin')),
    HWRow.builder(
      'forecast',
      maxItems: 5,
      spacing: 4,
      mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      item: HWColumn(
        children: [
          HWText.dateTime(
            HWItemData(
              HWDateTime('day'),
              previewValues: ['2026-09-21T12:00:00Z', '2026-09-22T12:00:00Z'],
            ),
            format: HWDateFormat.skeleton('E'),
          ),
          HWIcon(HWItemData(_condition, previewValues: [0xE88A, 0xE25B])),
          HWText.number(
            HWItemData(
              HWInt('temperature', defaultValue: 0),
              previewValues: [21, 17, 19],
            ),
          ),
          HWText.number(HWItemData(HWDouble('rain', previewValue: 0.5))),
          HWBoolConditional(
            data: HWItemData(HWBool('windy', defaultValue: false)),
            whenTrue: HWText.fixed('windy'),
            whenFalse: HWText.fixed('calm'),
          ),
          HWText(
            HWItemData(
              HWString.localized(
                'label',
                defaultTranslations: {'en': 'Day', 'de': 'Tag'},
                previewTranslations: {'en': 'Someday', 'de': 'Irgendwann'},
              ),
              previewValues: ['Mon'],
            ),
          ),
          HWText(HWItemData(HWString('note'))),
          HWText(HWString('unit', defaultValue: '°C')),
          HWDataExists(
            data: HWItemData(HWImageData('icon')),
            whenPresent: HWImage(
              HWItemData(
                HWImageData('icon', previewAsset: 'assets/sun.png'),
                previewValues: ['assets/rain.png'],
              ),
              width: 16,
            ),
            whenAbsent: HWText.fixed('-'),
          ),
        ],
      ),
      whenEmpty: HWText.fixed('No forecast yet'),
    ),
    HWColumn.builder(
      'notes',
      maxItems: 2,
      item: HWText(HWItemData(HWString('text', previewValue: 'Note'))),
    ),
    HWRow.builder('dots', maxItems: 3, item: HWText.fixed('.')),
  ],
);

/// A widget whose only data is one list.
const _listOnly = HWRow.builder(
  'forecast',
  maxItems: 3,
  item: HWText(HWItemData(HWString('label', previewValue: 'Day'))),
);

/// A time-based list beside a time-based field and an untimed list, its item
/// holding a date, an image, a number and a localized text.
const _timedLists = HWColumn(
  children: [
    HWText(HWTimedData(HWString('summary', previewValue: 'Sunny'))),
    HWRow.builder(
      'hourly',
      maxItems: 4,
      spacing: 4,
      item: HWColumn(
        children: [
          HWText.dateTime(
            HWTimedData(
              HWItemData(
                HWDateTime('time'),
                previewValues: ['2026-09-21T09:00:00Z', '2026-09-21T10:00:00Z'],
              ),
            ),
            format: HWDateFormat.jm,
          ),
          HWDataExists(
            data: HWTimedData(HWItemData(HWImageData('icon'))),
            whenPresent: HWImage(
              HWTimedData(
                HWItemData(
                  HWImageData('icon', previewAsset: 'assets/sun.png'),
                  previewValues: ['assets/rain.png'],
                ),
              ),
              width: 16,
            ),
            whenAbsent: HWText.fixed('-'),
          ),
          HWText.number(
            HWTimedData(
              HWItemData(
                HWInt('temperature', defaultValue: 0),
                previewValues: [12, 13],
              ),
            ),
          ),
          HWText(
            HWTimedData(
              HWItemData(
                HWString.localized(
                  'label',
                  defaultTranslations: {'en': 'Hour', 'de': 'Stunde'},
                  previewTranslations: {'en': 'Now', 'de': 'Jetzt'},
                ),
              ),
            ),
          ),
        ],
      ),
      whenEmpty: HWText.fixed('No hourly forecast'),
    ),
    HWColumn.builder(
      'notes',
      maxItems: 2,
      item: HWText(HWItemData(HWString('text', previewValue: 'Note'))),
    ),
  ],
);

/// A widget whose only data is one time-based list.
const _timedListOnly = HWRow.builder(
  'hourly',
  maxItems: 3,
  item: HWText(
    HWTimedData(HWItemData(HWString('label', previewValue: 'Now'))),
  ),
);

WidgetSpec _treeSpec(
  HWWidget tree, {
  required bool useLiveDataInPreview,
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Lists',
        useLiveDataInPreview: useLiveDataInPreview,
        iOS: const HomeWidgetIOSConfiguration(groupId: 'group.example'),
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      ),
      className: 'Lists',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

final _specs =
    <String, WidgetSpec Function({required bool useLiveDataInPreview})>{
  'every field': _fieldsSpec,
  'lists': ({required useLiveDataInPreview}) =>
      _treeSpec(_lists, useLiveDataInPreview: useLiveDataInPreview),
  'a list-only widget': ({required useLiveDataInPreview}) =>
      _treeSpec(_listOnly, useLiveDataInPreview: useLiveDataInPreview),
  'a timed list beside timed fields': ({required useLiveDataInPreview}) =>
      _treeSpec(_timedLists, useLiveDataInPreview: useLiveDataInPreview),
  'a timed list alone': ({required useLiveDataInPreview}) =>
      _treeSpec(_timedListOnly, useLiveDataInPreview: useLiveDataInPreview),
};

/// Makes the icon font of [_condition] resolvable from [projectRoot].
void _writeIconFontPackage(Directory projectRoot) {
  final package = writeFontPackage(
    projectRoot,
    'brand_icons',
    pubspecFonts: '''
    - family: BrandIcons
      fonts:
        - asset: fonts/BrandIcons.otf
''',
    assets: ['fonts/BrandIcons.otf'],
  );
  writeFontFixture(
    projectRoot,
    packages: [FixturePackage(name: 'brand_icons', root: package.path)],
  );
}

void main() {
  final skip = _unavailable();

  group(
    'preview widget Swift',
    () {
      for (final MapEntry(key: name, value: specOf) in _specs.entries) {
        for (final live in _liveDataInPreview) {
          test(
            'type-checks $name with live preview data ${live ? 'on' : 'off'}',
            () async {
              useMockLogger();
              resetFontResolverCaches();
              addTearDown(resetFontResolverCaches);
              final temp =
                  Directory.systemTemp.createTempSync('hw_swift_preview');
              addTearDown(() => temp.deleteSync(recursive: true));
              writeRunnerXcodeProject(temp);
              _writeIconFontPackage(temp);

              final spec = specOf(useLiveDataInPreview: live);
              await IosGenerator(spec: spec, projectRoot: temp).generate();

              final extensionDir = Directory(
                p.join(temp.path, 'ios', '${spec.className}HomeWidget'),
              );
              final result = Process.runSync('xcrun', [
                '-sdk',
                'iphonesimulator',
                'swiftc',
                '-typecheck',
                '-parse-as-library',
                '-application-extension',
                '-target',
                'arm64-apple-ios14.0-simulator',
                p.join(extensionDir.path, 'Widget.swift'),
                p.join(extensionDir.path, 'WidgetBundle.swift'),
              ]);

              expect(
                result.exitCode,
                0,
                reason: 'swiftc failed:\n${result.stdout}\n${result.stderr}',
              );
            },
            timeout: const Timeout(Duration(minutes: 3)),
          );
        }
      }
    },
    skip: skip,
  );
}
