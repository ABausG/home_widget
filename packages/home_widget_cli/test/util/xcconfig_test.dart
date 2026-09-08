import 'dart:io';

import 'package:home_widget_cli/src/util/xcconfig.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xcconfig_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File write(String name, String content) {
    final file = File('${tempDir.path}/$name')
      ..parent.createSync(recursive: true);
    return file..writeAsStringSync(content);
  }

  test('reads assignments and strips comments', () {
    final file = write(
      'Debug.xcconfig',
      '// leading comment\n'
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app // trailing\n'
          '\n'
          'OTHER_SWIFT_FLAGS = -DFOO\n',
    );

    expect(readXcconfigSettings(file), {
      'PRODUCT_BUNDLE_IDENTIFIER': 'com.example.app',
      'OTHER_SWIFT_FLAGS': '-DFOO',
    });
  });

  test('lets a later line win', () {
    final file = write(
      'Debug.xcconfig',
      'PRODUCT_BUNDLE_IDENTIFIER = com.example.app\n'
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev\n',
    );

    expect(
      readXcconfigSettings(file)['PRODUCT_BUNDLE_IDENTIFIER'],
      'com.example.app.dev',
    );
  });

  test('follows includes and lets the including file override them', () {
    write(
        'Generated.xcconfig',
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.app\n'
            'FLUTTER_TARGET = lib/main.dart\n');
    final file = write(
      'Debug-dev.xcconfig',
      '#include "Generated.xcconfig"\n'
          '#include? "Pods/Pods-Runner.debug.xcconfig"\n'
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev\n',
    );

    expect(readXcconfigSettings(file), {
      'PRODUCT_BUNDLE_IDENTIFIER': 'com.example.app.dev',
      'FLUTTER_TARGET': 'lib/main.dart',
    });
  });

  test('treats a missing file as empty', () {
    expect(
      readXcconfigSettings(File('${tempDir.path}/nope.xcconfig')),
      isEmpty,
    );
  });

  test('skips conditional assignments', () {
    final file = write(
      'Debug.xcconfig',
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements\n'
          'CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*] = Runner/Device.entitlements\n',
    );

    expect(
      readXcconfigSettings(file)['CODE_SIGN_ENTITLEMENTS'],
      'Runner/Runner.entitlements',
    );
  });

  test('survives a file that includes itself', () {
    final file = write(
      'Loop.xcconfig',
      '#include "Loop.xcconfig"\n'
          'PRODUCT_NAME = Runner\n',
    );

    expect(readXcconfigSettings(file), {'PRODUCT_NAME': 'Runner'});
  });
}
