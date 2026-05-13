import 'dart:io';

import 'package:home_widget_cli/src/util/android_wiring.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger mockLogger;
  late Directory root;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.err(any())).thenReturn(null);
    when(() => mockLogger.success(any())).thenReturn(null);

    root = Directory.systemTemp.createTempSync('hw_android_wiring_test');

    Directory(p.join(root.path, 'android', 'app')).createSync(recursive: true);
    File(p.join(root.path, 'android', 'app', 'build.gradle')).writeAsStringSync(
      '''
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    buildFeatures {
    }
}

dependencies {
}
''',
    );
    File(p.join(root.path, 'android', 'build.gradle')).writeAsStringSync(
      "ext.kotlin_version = '1.4.0'\n",
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('warns when Kotlin major < 2 and compose compiler version is unknown',
      () async {
    await ensureAndroidGlanceGradleSetup(root);

    verify(
      () => mockLogger.warn(
        any(
          that: allOf([
            contains('Kotlin 1.4.0'),
            contains('Compose compiler'),
          ]),
        ),
      ),
    ).called(1);
  });

  group('ensureAndroidManifestReceiver', () {
    late File manifestFile;

    setUp(() {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'main'),
      )..createSync(recursive: true);
      manifestFile = File(p.join(dir.path, 'AndroidManifest.xml'));
    });

    test('warns when manifest has no application element', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
      );

      verify(
        () => mockLogger.warn(
          any(that: contains('Could not find <application>')),
        ),
      ).called(1);
    });

    test('is idempotent when matching receiver already exists', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver android:name="com.test.FooHomeWidgetReceiver" />
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
      );
      final afterFirst = manifestFile.readAsStringSync();

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
      );
      final afterSecond = manifestFile.readAsStringSync();

      expect(afterFirst, afterSecond);
      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });

    test('treats relative receiver name containing WidgetReceiver as present',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver android:name=".FooHomeWidgetReceiver" />
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
      );

      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });
  });
}
