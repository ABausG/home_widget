@Tags(['integration', 'integration_ios'])
library;

import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

/// The deployment targets a generated widget extension can be built against.
///
/// `xcode_pbxproj_patcher.dart` writes 14.0 into a new extension target, so a
/// helper body that reaches for a newer API without an `#available` guard would
/// only fail once someone opened Xcode. 15.0 is the next step up, where the
/// guarded branch is the one that compiles.
const _targets = [
  'arm64-apple-ios14.0-simulator',
  'arm64-apple-ios15.0-simulator',
];

/// Exercises every helper the way generated code does, so an unguarded API or a
/// changed signature is a compile error rather than a runtime surprise.
const _driver = r'''
func hwHelperSmokeDriver() {
  let locale = hwFormatLocale()
  let zone = hwResolveTimeZone("Europe/Berlin")
  print(locale.identifier, zone.identifier)
  print(hwParseIsoDate("2026-09-02T10:00:00.123456Z") as Any)
  print(hwFormatDecimal(1234.5, minFraction: nil, maxFraction: nil, grouping: true))
  print(hwFormatDecimal(1234.5, minFraction: 1, maxFraction: 2, grouping: false))
  print(hwFormatPercent(0.5, minFraction: nil, maxFraction: 0))
  print(hwFormatCurrency(9.99, code: "EUR", decimals: nil))
  print(hwFormatCurrency(9.99, code: "", decimals: 2))
  print(hwFormatCompact(1200))
  print(hwFormatNumberPattern(-1234.5, "#,##0.00"))
  guard let date = hwParseIsoDate("2026-09-02T10:00:00Z") else { return }
  print(hwFormatDateSkeleton(date, "yMMMd"))
  print(hwFormatDateSkeleton(date, "yMMMd", timeZone: "Europe/Berlin"))
  print(hwFormatDatePattern(date, "dd.MM.yyyy HH:mm"))
  print(hwFormatDatePattern(date, "dd.MM.yyyy HH:mm", timeZone: "UTC"))
  print(hwFormatDateStyled(date, dateStyle: .medium, timeStyle: .short))
  print(hwFormatDateStyled(date, dateStyle: .full, timeStyle: .none, timeZone: "Asia/Tokyo"))

  let locales = hwCurrentLocales()
  print(hwResolveLocalized(locales, ["en": "Hi", "de": "Hallo"], baseLocale: "en") as Any)
  print(hwLocalize(["en": "Hi"], baseLocale: "en"))
  print(hwLocalizedEntries(["en": "Hi", "count": 1]))
  print(hwDecodeLocalized("{\"en\":\"Hi\"}") as Any)
  print(hwDecodeLocalized(nil) as Any)
  print(hwReadLocalized(UserDefaults.standard, "greeting", ["en": "Hi"], baseLocale: "en"))
  print(hwReadLocalized(nil, "greeting", ["en": "Hi"], baseLocale: "en"))
  print(hwReadTimedLocalized(["greeting": ["en": "Hi"]], "greeting", ["en": "Hi"], baseLocale: "en"))

  print(hwDecodeImage("/tmp/hw-does-not-exist.png", 100, 50) as Any)
  print(hwDecodeImage("assets/logo.png", nil, nil) as Any)
}
''';

/// Every helper body, each one after the helpers it calls, under the imports a
/// generated widget extension has plus the ones the helpers ask for.
String buildSwiftSource() {
  final emitted = <HWNativeHelper>{};
  final imports = <String>{
    'import UIKit',
    for (final helper in HWNativeHelper.values) ...helper.swiftImports,
  };
  final buffer = StringBuffer('${imports.join('\n')}\n\n');

  void write(HWNativeHelper helper) {
    if (!emitted.add(helper)) return;
    helper.dependencies.forEach(write);
    buffer
      ..writeln(helper.toSwift(0, dataExpr: 'entry.data'))
      ..writeln();
  }

  HWNativeHelper.values.forEach(write);
  buffer.writeln(_driver);
  return buffer.toString();
}

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
    'native helper Swift bodies',
    () {
      late Directory temp;
      late File source;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('hw_swift_helpers');
        source = File('${temp.path}/HWNativeHelpers.swift')
          ..writeAsStringSync(buildSwiftSource());
      });

      tearDown(() => temp.deleteSync(recursive: true));

      for (final target in _targets) {
        test(
          'type-check against $target',
          () {
            final result = Process.runSync('xcrun', [
              '-sdk',
              'iphonesimulator',
              'swiftc',
              '-typecheck',
              '-target',
              target,
              source.path,
            ]);

            expect(
              result.exitCode,
              0,
              reason: 'swiftc $target failed:\n'
                  '${result.stdout}\n${result.stderr}',
            );
          },
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    },
    skip: skip,
  );
}
