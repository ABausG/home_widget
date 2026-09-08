@Tags(['integration', 'integration_ios'])
library;

import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The compilation conditions a flavored build can be compiled with.
///
/// `xcode_pbxproj_patcher.dart` defines one per flavored configuration and none
/// for the unflavored ones, so both an active flavor and no flavor at all have
/// to compile — the `#else` branch of the flavor enum and the widget bundle
/// holding no widget are only reachable from the second.
const _conditions = <String, List<String>>{
  'HW_FLAVOR_DEV': ['-D', 'HW_FLAVOR_DEV'],
  'no flavor': [],
};

String? _unavailable() {
  try {
    final result = Process.runSync('xcrun', ['--find', 'swiftc']);
    if (result.exitCode != 0) return 'xcrun cannot find swiftc';
    return null;
  } on ProcessException {
    return 'xcrun is not available';
  }
}

void main() {
  final skip = _unavailable();

  group(
    'flavored widget Swift',
    () {
      late Directory temp;

      setUp(() async {
        temp = Directory.systemTemp.createTempSync('hw_swift_flavors');
        Directory(p.join(temp.path, 'ios')).createSync(recursive: true);

        final spec = WidgetSpec(
          data: HomeWidget(
            name: 'Weather',
            iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
            flavors: const {
              'dev': HomeWidgetFlavor(
                iOS: HomeWidgetIOSFlavor(groupId: 'group.example.dev'),
              ),
              'prod': HomeWidgetFlavor(),
            },
          ),
          className: 'Weather',
          dataFields: const [HWString('city'), HWInt('degrees')],
        );

        await IosGenerator(spec: spec, projectRoot: temp).generate();
      });

      tearDown(() => temp.deleteSync(recursive: true));

      _conditions.forEach((name, flags) {
        test(
          'type-checks with $name',
          () {
            final extensionDir =
                Directory(p.join(temp.path, 'ios', 'WeatherHomeWidget'));
            final result = Process.runSync('xcrun', [
              '-sdk',
              'iphonesimulator',
              'swiftc',
              '-typecheck',
              // The extension's `@main` bundle is a library entry point, not
              // top-level code.
              '-parse-as-library',
              // Matches APPLICATION_EXTENSION_API_ONLY on the generated target,
              // which is what makes the `iOSApplicationExtension` availability
              // checks in the generated helpers apply.
              '-application-extension',
              '-target',
              'arm64-apple-ios14.0-simulator',
              ...flags,
              p.join(extensionDir.path, 'Widget.swift'),
              p.join(extensionDir.path, 'WidgetBundle.swift'),
            ]);

            expect(
              result.exitCode,
              0,
              reason: 'swiftc ($name) failed:\n'
                  '${result.stdout}\n${result.stderr}',
            );
          },
          timeout: const Timeout(Duration(minutes: 3)),
        );
      });
    },
    skip: skip,
  );
}
