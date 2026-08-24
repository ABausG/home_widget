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

  test('reads applicationId from the Kotlin DSL build.gradle.kts', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle.kts'))
        .writeAsStringSync('''
android {
    defaultConfig {
        applicationId = "com.from.kts"
    }
}
''');
    expect(tryDetectAndroidPackage(root), 'com.from.kts');
  });

  test('reads the namespace from a Groovy build.gradle', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle'))
        .writeAsStringSync("""
android {
    namespace 'com.the.namespace'

    defaultConfig {
        applicationId 'com.other.id'
    }
}
""");
    expect(tryDetectAndroidNamespace(root), 'com.the.namespace');
  });

  test('reads the namespace from a Kotlin DSL build.gradle.kts', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle.kts'))
        .writeAsStringSync('''
android {
    namespace = "com.kts.namespace"

    defaultConfig {
        applicationId = "com.other.id"
    }
}
''');
    expect(tryDetectAndroidNamespace(root), 'com.kts.namespace');
  });

  test('falls back to the manifest package when no namespace is declared', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle'))
        .writeAsStringSync("""
android {
    defaultConfig {
        applicationId 'com.other.id'
    }
}
""");
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
    package="com.legacy.pkg">
</manifest>
''');
    expect(tryDetectAndroidNamespace(root), 'com.legacy.pkg');
  });

  test('returns null when neither namespace nor manifest package exists', () {
    expect(tryDetectAndroidNamespace(root), isNull);
  });
}
