import 'dart:io';

import 'package:home_widget_cli/src/util/android_wiring.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:xml/xml.dart';

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
        updated,
        contains('android:label="@string/home_widget_foo_label"'),
      );
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

  group('ensureAndroidManifestReceiver with flavors', () {
    late File mainManifest;

    File flavorManifest(String flavor) => File(
          p.join(
            root.path,
            'android',
            'app',
            'src',
            flavor,
            'AndroidManifest.xml',
          ),
        );

    void writeMainManifest({String extraApplicationChildren = ''}) {
      mainManifest.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application android:label="test">
        <activity android:name=".MainActivity" />$extraApplicationChildren
    </application>
</manifest>
''',
      );
    }

    Future<void> ensure({List<String> flavors = const []}) =>
        ensureAndroidManifestReceiver(
          root,
          widgetClassName: 'FooHomeWidget',
          appPackageName: 'com.test',
          providerInfoName: 'foo_home_widget',
          handleLocaleChange: true,
          label: '@string/home_widget_foo_label',
          flavors: flavors,
        );

    setUp(() {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'main'),
      )..createSync(recursive: true);
      mainManifest = File(p.join(dir.path, 'AndroidManifest.xml'));
      writeMainManifest();
    });

    test('creates a flavor manifest carrying the receiver', () async {
      await ensure(flavors: ['dev', 'prod']);

      for (final flavor in ['dev', 'prod']) {
        final content = flavorManifest(flavor).readAsStringSync();
        expect(
          content,
          contains(
            'xmlns:android="http://schemas.android.com/apk/res/android"',
          ),
        );
        expect(
          content,
          contains('android:name="com.test.FooHomeWidgetReceiver"'),
        );
        expect(
          content,
          contains('android:label="@string/home_widget_foo_label"'),
        );
        expect(content, contains('@xml/foo_home_widget'));
        expect(
          content,
          contains('android:name="android.intent.action.LOCALE_CHANGED"'),
        );

        final receivers =
            XmlDocument.parse(content).rootElement.findAllElements('receiver');
        expect(receivers.length, 1);
      }

      expect(
        mainManifest.readAsStringSync(),
        isNot(contains('FooHomeWidgetReceiver')),
      );
    });

    test('marks a manifest it created and keeps the marker across runs',
        () async {
      const marker = '<!-- CREATED AND MANAGED BY THE home_widget CLI - IT '
          'ADDS AND REMOVES ITS OWN WIDGET RECEIVERS HERE -->';

      await ensure(flavors: ['dev']);

      expect(
        flavorManifest('dev').readAsStringSync(),
        startsWith('<?xml version="1.0" encoding="utf-8"?>\n$marker\n'),
      );

      // A second widget rewrites the file through the parse -> write round
      // trip, which has to leave the comment where it is.
      await ensureAndroidManifestReceiver(
        root,
        widgetClassName: 'BarHomeWidget',
        appPackageName: 'com.test',
        providerInfoName: 'bar_home_widget',
        flavors: const ['dev'],
      );

      final content = flavorManifest('dev').readAsStringSync();
      expect(
        content,
        startsWith('<?xml version="1.0" encoding="utf-8"?>\n$marker\n'),
      );
      expect(content, contains('FooHomeWidgetReceiver'));
      expect(content, contains('BarHomeWidgetReceiver'));
    });

    test('never marks a manifest it did not create', () async {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'dev'),
      )..createSync(recursive: true);
      File(p.join(dir.path, 'AndroidManifest.xml')).writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Dev" />
</manifest>
''',
      );

      await ensure(flavors: ['dev']);
      await ensure();

      expect(
        flavorManifest('dev').readAsStringSync(),
        isNot(contains('CREATED AND MANAGED')),
      );
      expect(
        mainManifest.readAsStringSync(),
        isNot(contains('CREATED AND MANAGED')),
      );
    });

    test('moves the receiver out of main and back again', () async {
      await ensure();
      expect(
        mainManifest.readAsStringSync(),
        contains('FooHomeWidgetReceiver'),
      );

      await ensure(flavors: ['dev']);
      expect(
        mainManifest.readAsStringSync(),
        isNot(contains('FooHomeWidgetReceiver')),
      );
      expect(
        flavorManifest('dev').readAsStringSync(),
        contains('FooHomeWidgetReceiver'),
      );
      // The app's own declarations survive the removal.
      expect(
        mainManifest.readAsStringSync(),
        contains('android:name=".MainActivity"'),
      );

      await ensure();
      expect(
        mainManifest.readAsStringSync(),
        contains('FooHomeWidgetReceiver'),
      );
      expect(
        flavorManifest('dev').readAsStringSync(),
        isNot(contains('FooHomeWidgetReceiver')),
      );
    });

    test('is idempotent across repeated runs', () async {
      await ensure(flavors: ['dev']);
      final mainAfterFirst = mainManifest.readAsStringSync();
      final flavorAfterFirst = flavorManifest('dev').readAsStringSync();

      await ensure(flavors: ['dev']);

      expect(mainManifest.readAsStringSync(), mainAfterFirst);
      expect(flavorManifest('dev').readAsStringSync(), flavorAfterFirst);
    });

    test('drops the receiver from a flavor that is no longer declared',
        () async {
      await ensure(flavors: ['dev', 'prod']);

      await ensure(flavors: ['dev']);

      expect(
        flavorManifest('dev').readAsStringSync(),
        contains('FooHomeWidgetReceiver'),
      );
      expect(
        flavorManifest('prod').readAsStringSync(),
        isNot(contains('FooHomeWidgetReceiver')),
      );
    });

    test('keeps the rest of an existing flavor manifest', () async {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'dev'),
      )..createSync(recursive: true);
      File(p.join(dir.path, 'AndroidManifest.xml')).writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="Dev">
        <activity android:name=".DevOnlyActivity" />
    </application>
</manifest>
''',
      );

      await ensure(flavors: ['dev']);

      final content = flavorManifest('dev').readAsStringSync();
      expect(content, contains('android.permission.INTERNET'));
      expect(content, contains('android:name=".DevOnlyActivity"'));
      expect(content, contains('android:label="Dev"'));
      expect(content, contains('FooHomeWidgetReceiver'));
    });

    test('adds an application element to a flavor manifest without one',
        () async {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'dev'),
      )..createSync(recursive: true);
      File(p.join(dir.path, 'AndroidManifest.xml')).writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
''',
      );

      await ensure(flavors: ['dev']);

      final document = XmlDocument.parse(
        flavorManifest('dev').readAsStringSync(),
      );
      final application =
          document.rootElement.findElements('application').single;
      expect(
        application
            .findElements('receiver')
            .single
            .getAttribute('android:name'),
        'com.test.FooHomeWidgetReceiver',
      );
      verifyNever(() => mockLogger.warn(any()));
    });

    test('only removes the receiver it owns', () async {
      writeMainManifest(
        extraApplicationChildren: '''
        <receiver
            android:name="com.test.AdaptiveFooHomeWidgetReceiver"
            android:label="@string/home_widget_adaptive_foo_label"
            android:exported="true">
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/adaptive_foo_home_widget" />
        </receiver>''',
      );

      await ensure(flavors: ['dev']);

      final content = mainManifest.readAsStringSync();
      expect(content, contains('AdaptiveFooHomeWidgetReceiver'));
      expect(content, contains('@xml/adaptive_foo_home_widget'));
      expect(content, isNot(contains('"com.test.FooHomeWidgetReceiver"')));
    });

    test('warns and writes nothing when the main manifest is missing',
        () async {
      mainManifest.deleteSync();

      await ensure();

      verify(
        () => mockLogger.warn(
          any(that: contains('AndroidManifest.xml not found')),
        ),
      ).called(1);
      expect(mainManifest.existsSync(), isFalse);
    });
  });

  group('ensureAndroidManifestScheduledUpdates', () {
    late File manifestFile;

    setUp(() {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'main'),
      )..createSync(recursive: true);
      manifestFile = File(p.join(dir.path, 'AndroidManifest.xml'));
    });

    void writeBareManifest() {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application android:label="test">
        <activity android:name=".MainActivity" />
    </application>
</manifest>
''',
      );
    }

    test('warns when the manifest is missing', () async {
      await ensureAndroidManifestScheduledUpdates(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('AndroidManifest.xml not found')),
        ),
      ).called(1);
    });

    test('warns when the manifest is not parsable XML', () async {
      manifestFile.writeAsStringSync('not xml <<<');

      await ensureAndroidManifestScheduledUpdates(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('Could not parse AndroidManifest.xml')),
        ),
      ).called(1);
    });

    test('warns when manifest has no application element', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
</manifest>
''',
      );

      await ensureAndroidManifestScheduledUpdates(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('Could not find <application>')),
        ),
      ).called(1);
    });

    test('adds the boot permission and the scheduling receiver', () async {
      writeBareManifest();

      await ensureAndroidManifestScheduledUpdates(root);

      final content = manifestFile.readAsStringSync();
      expect(
        content,
        contains(
          '<uses-permission android:name='
          '"android.permission.RECEIVE_BOOT_COMPLETED" />',
        ),
      );
      expect(content, contains('android:name="$scheduledUpdateReceiverFqcn"'));
      expect(content, contains('android:exported="false"'));
      expect(
        content,
        contains(
          '<action android:name="android.intent.action.BOOT_COMPLETED" />',
        ),
      );
      expect(
        content,
        contains(
          '<action android:name="android.intent.action.MY_PACKAGE_REPLACED" />',
        ),
      );
      expect(
        content,
        contains(
          '<action android:name='
          '"android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />',
        ),
      );

      // The receiver belongs inside <application>, the permission outside it.
      final document = XmlDocument.parse(content);
      final application = document.rootElement.childElements
          .firstWhere((e) => e.localName == 'application');
      expect(
        application.childElements
            .where((e) => e.localName == 'receiver')
            .map((e) => e.getAttribute('android:name')),
        contains(scheduledUpdateReceiverFqcn),
      );
      expect(
        document.rootElement.childElements
            .where((e) => e.localName == 'uses-permission')
            .length,
        1,
      );

      verify(
        () => mockLogger.detail(any(that: contains('Updated:'))),
      ).called(1);
    });

    test('is idempotent across repeated runs', () async {
      writeBareManifest();

      await ensureAndroidManifestScheduledUpdates(root);
      final afterFirst = manifestFile.readAsStringSync();

      await ensureAndroidManifestScheduledUpdates(root);
      final afterSecond = manifestFile.readAsStringSync();

      expect(afterSecond, afterFirst);
      verify(
        () => mockLogger.detail(any(that: contains('Updated:'))),
      ).called(1);
    });

    test('leaves a manifest that already declares everything untouched',
        () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application android:label="test">
        <receiver
            android:name="$scheduledUpdateReceiverFqcn"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
''',
      );
      final before = manifestFile.readAsStringSync();

      await ensureAndroidManifestScheduledUpdates(root);

      expect(manifestFile.readAsStringSync(), before);
      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });

    test(
        'adds the missing SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED '
        'action to a previously generated receiver', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application android:label="test">
        <receiver
            android:name="$scheduledUpdateReceiverFqcn"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestScheduledUpdates(root);

      final content = manifestFile.readAsStringSync();
      expect(
        content,
        contains(
          '<action android:name='
          '"android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />',
        ),
      );
      expect(
        content,
        contains(
          '<action android:name="android.intent.action.BOOT_COMPLETED" />',
        ),
      );
      expect(
        content,
        contains(
          '<action android:name="android.intent.action.MY_PACKAGE_REPLACED" />',
        ),
      );
      // The receiver is not duplicated.
      expect(
        'android:name="$scheduledUpdateReceiverFqcn"'
            .allMatches(content)
            .length,
        1,
      );
      verify(
        () => mockLogger.detail(any(that: contains('Updated:'))),
      ).called(1);

      // A second run must not append the action again.
      final afterFirst = content;
      await ensureAndroidManifestScheduledUpdates(root);
      expect(manifestFile.readAsStringSync(), afterFirst);
    });

    test(
        'does not duplicate a hand-written receiver that already has the '
        'action', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application android:label="test">
        <receiver
            android:name="$scheduledUpdateReceiverFqcn"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestScheduledUpdates(root);

      final content = manifestFile.readAsStringSync();
      expect(
        'SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED'
            .allMatches(content)
            .length,
        1,
      );
      expect(
        'android:name="$scheduledUpdateReceiverFqcn"'
            .allMatches(content)
            .length,
        1,
      );
      verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));
    });

    test('adds only the missing receiver when the permission exists', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application android:label="test" />
</manifest>
''',
      );

      await ensureAndroidManifestScheduledUpdates(root);

      final document = XmlDocument.parse(manifestFile.readAsStringSync());
      expect(
        document.rootElement.childElements
            .where((e) => e.localName == 'uses-permission')
            .length,
        1,
      );
      expect(
        document.rootElement
            .findAllElements('receiver')
            .map((e) => e.getAttribute('android:name')),
        contains(scheduledUpdateReceiverFqcn),
      );
    });
  });

  group('ensureAndroidManifestLaunchIntent', () {
    late File manifestFile;

    setUp(() {
      final dir = Directory(
        p.join(root.path, 'android', 'app', 'src', 'main'),
      )..createSync(recursive: true);
      manifestFile = File(p.join(dir.path, 'AndroidManifest.xml'));
    });

    void writeManifest({String extraActivityChildren = ''}) {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application android:label="test">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>$extraActivityChildren
        </activity>
    </application>
</manifest>
''',
      );
    }

    test('warns when the manifest is missing', () async {
      await ensureAndroidManifestLaunchIntent(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('AndroidManifest.xml not found')),
        ),
      ).called(1);
    });

    test('warns when the manifest is not parsable XML', () async {
      manifestFile.writeAsStringSync('not xml <<<');

      await ensureAndroidManifestLaunchIntent(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('Could not parse AndroidManifest.xml')),
        ),
      ).called(1);
    });

    test('warns when manifest has no application element', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
</manifest>
''',
      );

      await ensureAndroidManifestLaunchIntent(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('Could not find <application>')),
        ),
      ).called(1);
    });

    test('warns when no launcher activity is declared', () async {
      manifestFile.writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test">
    <application android:label="test">
        <activity android:name=".OtherActivity" />
    </application>
</manifest>
''',
      );

      await ensureAndroidManifestLaunchIntent(root);

      verify(
        () => mockLogger.warn(
          any(that: contains('Could not find the launcher activity')),
        ),
      ).called(1);
      expect(
        manifestFile.readAsStringSync(),
        isNot(contains(homeWidgetLaunchAction)),
      );
    });

    test('adds the launch intent-filter to the launcher activity', () async {
      writeManifest();

      await ensureAndroidManifestLaunchIntent(root);

      final content = manifestFile.readAsStringSync();
      expect(
        content,
        contains('<action android:name="$homeWidgetLaunchAction"'),
      );

      final document = XmlDocument.parse(content);
      final activity = document.rootElement.findAllElements('activity').single;
      expect(
        activity.childElements
            .where((e) => e.localName == 'intent-filter')
            .length,
        2,
      );
      // The launcher filter keeps its own actions.
      expect(
        content,
        contains('<action android:name="android.intent.action.MAIN" />'),
      );
    });

    test('is idempotent across repeated runs', () async {
      writeManifest();

      await ensureAndroidManifestLaunchIntent(root);
      final afterFirst = manifestFile.readAsStringSync();
      await ensureAndroidManifestLaunchIntent(root);

      expect(manifestFile.readAsStringSync(), afterFirst);
      expect(
        homeWidgetLaunchAction.allMatches(afterFirst).length,
        1,
      );
    });

    test('leaves a hand-written launch intent-filter untouched', () async {
      writeManifest(
        extraActivityChildren: '''
            <intent-filter>
                <action android:name="$homeWidgetLaunchAction" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>''',
      );
      final before = manifestFile.readAsStringSync();

      await ensureAndroidManifestLaunchIntent(root);

      expect(manifestFile.readAsStringSync(), before);
    });
  });
}
