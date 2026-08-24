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

    test('is idempotent when matching receiver already has the label',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label" />
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        label: '@string/home_widget_foo_label',
      );
      final afterFirst = manifestFile.readAsStringSync();

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        label: '@string/home_widget_foo_label',
      );
      final afterSecond = manifestFile.readAsStringSync();

      expect(afterFirst, afterSecond);
      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });

    test('updates android:label when an existing receiver is stale', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="FooHomeWidget"
            android:exported="true">
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/foo_home_widget" />
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      expect(
          updated, contains('android:label="@string/home_widget_foo_label"'));
      expect(updated, isNot(contains('android:label="FooHomeWidget"')));
      verify(() => mockLogger.detail(any(that: contains('Updated:'))))
          .called(1);
    });

    test('treats relative receiver name containing WidgetReceiver as present',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name=".FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label" />
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        label: '@string/home_widget_foo_label',
      );

      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });

    test('adds LOCALE_CHANGED to a newly created receiver', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        handleLocaleChange: true,
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      expect(
        updated,
        contains('android:name="android.appwidget.action.APPWIDGET_UPDATE"'),
      );
      expect(
        updated,
        contains('android:name="android.intent.action.LOCALE_CHANGED"'),
      );
    });

    test('leaves a non-localized widget receiver without LOCALE_CHANGED',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      expect(
        updated,
        contains('android:name="android.appwidget.action.APPWIDGET_UPDATE"'),
      );
      expect(updated, isNot(contains('LOCALE_CHANGED')));
    });

    test('adds LOCALE_CHANGED to an existing receiver that lacks it', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/foo_home_widget" />
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        handleLocaleChange: true,
        label: '@string/home_widget_foo_label',
      );
      final afterFirst = manifestFile.readAsStringSync();

      expect(
        afterFirst,
        contains('android:name="android.intent.action.LOCALE_CHANGED"'),
      );
      expect(
        afterFirst,
        contains('android:name="android.appwidget.action.APPWIDGET_UPDATE"'),
      );
      expect('LOCALE_CHANGED'.allMatches(afterFirst).length, 1);

      // A second run must not append the action again.
      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        handleLocaleChange: true,
        label: '@string/home_widget_foo_label',
      );

      expect(manifestFile.readAsStringSync(), afterFirst);
      verify(() => mockLogger.detail(any(that: contains('Updated:'))))
          .called(1);
    });

    test(
        'declares android:exported when creating the first intent-filter on an '
        'existing receiver', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label">
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/foo_home_widget" />
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        handleLocaleChange: true,
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      expect(updated, contains('android:exported="true"'));
      expect(updated, contains('<intent-filter>'));
      expect(
        updated,
        contains('android:name="android.intent.action.LOCALE_CHANGED"'),
      );
    });

    test('keeps an explicit android:exported="false" when adding the filter',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label"
            android:exported="false">
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/foo_home_widget" />
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        handleLocaleChange: true,
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      expect(updated, contains('android:exported="false"'));
      expect(updated, isNot(contains('android:exported="true"')));
      expect(
        updated,
        contains('android:name="android.intent.action.LOCALE_CHANGED"'),
      );
    });

    test('does not add android:exported when the intent-filter already exists',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/foo_home_widget" />
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        handleLocaleChange: true,
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      expect(
        updated,
        contains('android:name="android.intent.action.LOCALE_CHANGED"'),
      );
      expect(updated, isNot(contains('android:exported')));
    });

    test('keeps an existing android:label when the caller omits one', () async {
      const original = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.FooHomeWidgetReceiver"
            android:label="@string/home_widget_foo_label"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/foo_home_widget" />
        </receiver>
    </application>
</manifest>
''';
      manifestFile.writeAsStringSync(original);

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
      );

      final updated = manifestFile.readAsStringSync();
      expect(
        updated,
        contains('android:label="@string/home_widget_foo_label"'),
      );
      expect(updated, isNot(contains('android:label="FooHomeWidget"')));
      expect(updated, original);
      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });

    test('does not match a receiver whose name merely ends with the class name',
        () async {
      // `FooHomeWidgetReceiver` is a suffix of `AdaptiveFooHomeWidgetReceiver`;
      // a substring match would find (and relabel) the wrong widget's receiver.
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application>
        <receiver
            android:name="com.test.AdaptiveFooHomeWidgetReceiver"
            android:label="@string/home_widget_adaptive_foo_label"
            android:exported="true">
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/adaptive_foo_home_widget" />
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'FooHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'foo_home_widget',
        label: '@string/home_widget_foo_label',
      );

      final updated = manifestFile.readAsStringSync();
      // The other widget's receiver keeps its label untouched...
      expect(
        updated,
        contains('android:label="@string/home_widget_adaptive_foo_label"'),
      );
      // ...and Foo gets its own receiver element added.
      expect(
        updated,
        contains('android:name="com.test.FooHomeWidgetReceiver"'),
      );
      expect(updated, contains('@xml/foo_home_widget'));
    });
  });
}
