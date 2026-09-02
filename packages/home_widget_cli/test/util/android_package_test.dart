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

  test('does not read a same-suffix property as the applicationId', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle'))
        .writeAsStringSync("""
android {
    defaultConfig {
        testApplicationId "com.example.test"
    }
}
""");
    expect(tryDetectAndroidPackage(root), isNull);
  });

  test('prefers the real applicationId over a same-suffix property', () {
    File(p.join(root.path, 'android', 'app', 'build.gradle'))
        .writeAsStringSync("""
android {
    defaultConfig {
        testApplicationId "com.example.test"
        applicationId "com.example.real"
    }
}
""");
    expect(tryDetectAndroidPackage(root), 'com.example.real');
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

  group('tryDetectAndroidLauncherActivity', () {
    void writeManifest(String body, {String? package}) {
      final packageAttribute =
          package == null ? '' : '\n    package="$package"';
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
<manifest xmlns:android="http://schemas.android.com/apk/res/android"$packageAttribute>
$body
</manifest>
''');
    }

    void writeApplicationId(String applicationId) {
      File(p.join(root.path, 'android', 'app', 'build.gradle'))
          .writeAsStringSync('''
android {
    defaultConfig {
        applicationId "$applicationId"
    }
}
''');
    }

    const launcherFilter = '''
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>''';

    test('resolves a relative name against the manifest package', () {
      writeManifest(
        '''
    <application>
        <activity android:name=".MainActivity">$launcherFilter
        </activity>
    </application>''',
        package: 'com.manifest.pkg',
      );
      writeApplicationId('com.detected.app');

      expect(
        tryDetectAndroidLauncherActivity(root),
        'com.manifest.pkg.MainActivity',
      );
    });

    test('resolves a relative name against the namespace, not the app id', () {
      writeManifest('''
    <application>
        <activity android:name=".MainActivity">$launcherFilter
        </activity>
    </application>''');
      File(p.join(root.path, 'android', 'app', 'build.gradle'))
          .writeAsStringSync('''
android {
    namespace "com.the.namespace"

    defaultConfig {
        applicationId "com.detected.app"
    }
}
''');

      expect(
        tryDetectAndroidLauncherActivity(root),
        'com.the.namespace.MainActivity',
      );
    });

    test('resolves a relative name against the app id without a namespace', () {
      writeManifest('''
    <application>
        <activity android:name=".MainActivity">$launcherFilter
        </activity>
    </application>''');
      writeApplicationId('com.detected.app');

      expect(
        tryDetectAndroidLauncherActivity(root),
        'com.detected.app.MainActivity',
      );
    });

    test('resolves a bare name against the detected application id', () {
      writeManifest('''
    <application>
        <activity android:name="HostActivity">$launcherFilter
        </activity>
    </application>''');
      writeApplicationId('com.detected.app');

      expect(
        tryDetectAndroidLauncherActivity(root),
        'com.detected.app.HostActivity',
      );
    });

    test('keeps a fully qualified name', () {
      writeManifest('''
    <application>
        <activity android:name="com.other.pkg.Launcher">$launcherFilter
        </activity>
    </application>''');

      expect(
        tryDetectAndroidLauncherActivity(root),
        'com.other.pkg.Launcher',
      );
    });

    test('skips activities that are not the launcher', () {
      writeManifest(
        '''
    <application>
        <activity android:name=".ShareActivity">
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
            </intent-filter>
        </activity>
        <activity android:name=".MainActivity">$launcherFilter
        </activity>
    </application>''',
        package: 'com.example.app',
      );

      expect(
        tryDetectAndroidLauncherActivity(root),
        'com.example.app.MainActivity',
      );
    });

    test('returns null when no launcher activity is declared', () {
      writeManifest('''
    <application>
        <activity android:name=".ShareActivity" />
    </application>''');

      expect(tryDetectAndroidLauncherActivity(root), isNull);
    });

    test('returns null when the manifest is missing', () {
      expect(tryDetectAndroidLauncherActivity(root), isNull);
    });

    test('returns null when a relative name cannot be resolved', () {
      writeManifest('''
    <application>
        <activity android:name=".MainActivity">$launcherFilter
        </activity>
    </application>''');

      expect(tryDetectAndroidLauncherActivity(root), isNull);
    });
  });
}
