import 'dart:io';

import 'package:home_widget_cli/src/util/android_package.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('hw_android_pkg_test');
    Directory(p.join(root.path, 'android', 'app', 'src', 'main'))
        .createSync(recursive: true);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('reads package name from manifest package attribute', () {
    File(
      p.join(
        root.path,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.from.manifest">
</manifest>
''');
    expect(tryDetectAndroidPackage(root), 'com.from.manifest');
  });

  test('falls back to regex when manifest XML cannot be parsed for package',
      () {
    File(
      p.join(
        root.path,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).writeAsStringSync('<manifest package="com.regex.fallback"');
    expect(tryDetectAndroidPackage(root), 'com.regex.fallback');
  });

  test('reads applicationId from app build.gradle', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle'))
        .writeAsStringSync("""
android {
    namespace 'ignored'
}

defaultConfig {
    applicationId 'com.from.gradle'
}
""");
    expect(tryDetectAndroidPackage(root), 'com.from.gradle');
  });
}
