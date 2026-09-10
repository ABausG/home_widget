@Tags(['integration', 'integration_ios'])
library;

import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
WidgetSpec _spec({required bool useLiveDataInPreview}) => WidgetSpec(
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

void main() {
  final skip = _unavailable();

  group(
    'preview widget Swift',
    () {
      for (final live in _liveDataInPreview) {
        test(
          'type-checks with live preview data ${live ? 'on' : 'off'}',
          () async {
            final temp =
                Directory.systemTemp.createTempSync('hw_swift_preview');
            addTearDown(() => temp.deleteSync(recursive: true));
            Directory(p.join(temp.path, 'ios')).createSync(recursive: true);

            await IosGenerator(
              spec: _spec(useLiveDataInPreview: live),
              projectRoot: temp,
            ).generate();

            final extensionDir =
                Directory(p.join(temp.path, 'ios', 'WeatherHomeWidget'));
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
    },
    skip: skip,
  );
}
