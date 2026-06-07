import 'dart:io';

import 'package:home_widget_cli/src/util/android_package.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/fake_progress.dart';
import '../helpers/run_cli_in_project.dart';
import '../helpers/test_flutter_project.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
    logger = mockLogger;
    // Default prompt behavior to return default value (empty string usually means use default in prompt logic if no default is provided, but here prompt returns a string)
    // In CreateCommand: confirm input. If I mock it to return 'group.id', it simulates user input.
    when(
      () => mockLogger.prompt(any(), defaultValue: any(named: 'defaultValue')),
    ).thenReturn('');
    when(() => mockLogger.progress(any())).thenReturn(FakeProgress());
    when(() => mockLogger.progress(any(), options: any(named: 'options')))
        .thenReturn(FakeProgress());
    when(() => mockLogger.detail(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.success(any())).thenReturn(null);
    when(() => mockLogger.warn(any())).thenReturn(null);
    when(() => mockLogger.err(any())).thenReturn(null);
  });

  void expectAndroidScaffold({
    required Directory projectRoot,
    required String widgetClassName,
  }) {
    final androidManifest = File(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    );
    expect(androidManifest.existsSync(), isTrue);
    final manifestText = androidManifest.readAsStringSync();

    final packageName = tryDetectAndroidPackage(projectRoot);
    expect(packageName, isNotNull);

    final packagePath = packageName!.split('.').join(p.separator);
    final kotlinDir = Directory(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        packagePath,
      ),
    );

    expect(
      File(p.join(kotlinDir.path, '$widgetClassName.kt')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(kotlinDir.path, '${widgetClassName}Receiver.kt'))
          .existsSync(),
      isTrue,
    );

    final providerInfo = File(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'res',
        'xml',
        'example_home_widget.xml',
      ),
    );
    expect(providerInfo.existsSync(), isTrue);

    // AndroidManifest wiring (best-effort).
    expect(manifestText, contains('${widgetClassName}Receiver'));
    expect(manifestText, contains('@xml/example_home_widget'));
  }

  void expectIosScaffold({
    required Directory projectRoot,
    required String widgetClassName,
  }) {
    final iosExtensionDir =
        Directory(p.join(projectRoot.path, 'ios', widgetClassName));
    expect(iosExtensionDir.existsSync(), isTrue);
    expect(
      File(p.join(iosExtensionDir.path, 'Widget.swift')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(iosExtensionDir.path, 'WidgetBundle.swift')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(iosExtensionDir.path, 'Info.plist')).existsSync(),
      isTrue,
    );
  }

  test(
    'create scaffolds both android and ios by default when folders exist',
    () async {
      final project = await TestFlutterProject.create();
      final code =
          await runCliWithProjectRoot(project.root, ['create', 'Example']);
      expect(code, 0);

      final widgetClassName = 'ExampleHomeWidget';

      expectAndroidScaffold(
        projectRoot: project.root,
        widgetClassName: widgetClassName,
      );
      expectIosScaffold(
        projectRoot: project.root,
        widgetClassName: widgetClassName,
      );

      verify(
        () => mockLogger.success(
          any(that: contains('Widget scaffolded successfully')),
        ),
      ).called(1);
      verify(
        () => mockLogger.info(
          any(
            that: allOf(
              contains('Thanks for using home_widget'),
              contains('github.com/sponsors/ABausG'),
            ),
          ),
          style: any(named: 'style'),
        ),
      ).called(1);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  group('android Gradle DSL variants', () {
    Future<void> expectAndroidGradlePatched({
      required Directory projectRoot,
      required AndroidAppGradleDsl dsl,
    }) async {
      final appDir = Directory(p.join(projectRoot.path, 'android', 'app'));
      expect(appDir.existsSync(), isTrue);

      final f = File(
        p.join(
          appDir.path,
          dsl == AndroidAppGradleDsl.groovy
              ? 'build.gradle'
              : 'build.gradle.kts',
        ),
      );
      expect(
        f.existsSync(),
        isTrue,
        reason: 'Expected Gradle file to exist for $dsl: ${f.path}',
      );

      final text = await f.readAsString();

      // Dialect-specific insertion: dependency line differs.
      switch (dsl) {
        case AndroidAppGradleDsl.groovy:
          expect(
            text,
            contains("implementation 'androidx.glance:glance-appwidget:"),
          );
          expect(text, contains('compose true'));
          break;
        case AndroidAppGradleDsl.kts:
          expect(
            text,
            contains('implementation("androidx.glance:glance-appwidget:'),
          );
          expect(text, contains('compose = true'));
          break;
      }
    }

    for (final dsl in AndroidAppGradleDsl.values) {
      test(
        'create patches android/app/build.gradle(.kts) for $dsl',
        () async {
          final project = await TestFlutterProject.create(includeIos: false);

          // Force Groovy by replacing the app gradle file in test only.
          await project.setAndroidAppGradleDsl(dsl);

          final code = await runCliWithProjectRoot(
            project.root,
            ['create', '--android', 'Example'],
          );
          expect(code, 0);

          await expectAndroidGradlePatched(projectRoot: project.root, dsl: dsl);
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );
    }
  });

  test(
    'create --android only scaffolds android',
    () async {
      final project = await TestFlutterProject.create();
      final code = await runCliWithProjectRoot(
        project.root,
        ['create', '--android', 'Example'],
      );
      expect(code, 0);

      expectAndroidScaffold(
        projectRoot: project.root,
        widgetClassName: 'ExampleHomeWidget',
      );

      final iosExtensionDir =
          Directory(p.join(project.root.path, 'ios', 'ExampleHomeWidget'));
      expect(iosExtensionDir.existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'create with no android/ios folders and no flags does nothing',
    () async {
      final project = await TestFlutterProject.create(
        includeAndroid: false,
        includeIos: false,
      );
      final code =
          await runCliWithProjectRoot(project.root, ['create', 'Example']);
      expect(code, 0);

      expect(
        Directory(p.join(project.root.path, 'android')).existsSync(),
        isFalse,
      );
      expect(Directory(p.join(project.root.path, 'ios')).existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'create --android warns when android/ is missing',
    () async {
      final project = await TestFlutterProject.create(
        includeAndroid: false,
        includeIos: false,
      );
      final code = await runCliWithProjectRoot(
        project.root,
        ['create', '--android', 'Example'],
      );
      expect(code, 0);

      verify(
        () => mockLogger.warn(
          any(
            that: contains(
              'Requested Android scaffolding but no android/ folder exists',
            ),
          ),
        ),
      ).called(1);

      // Still no Android/iOS scaffolding should be created without folders.
      expect(
        Directory(p.join(project.root.path, 'android')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(project.root.path, 'ios', 'ExampleHomeWidget'))
            .existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'create --ios warns when ios/ is missing',
    () async {
      final project = await TestFlutterProject.create(
        includeAndroid: false,
        includeIos: false,
      );
      final code = await runCliWithProjectRoot(
        project.root,
        ['create', '--ios', 'Example'],
      );
      expect(code, 0);

      verify(
        () => mockLogger.warn(
          any(
            that: contains(
              'Requested iOS scaffolding but no ios/ folder exists',
            ),
          ),
        ),
      ).called(1);

      expect(Directory(p.join(project.root.path, 'ios')).existsSync(), isFalse);
      expect(
        Directory(p.join(project.root.path, 'android', 'app')).existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'create defaults to android-only when only android/ exists',
    () async {
      final project = await TestFlutterProject.create(includeIos: false);

      final code =
          await runCliWithProjectRoot(project.root, ['create', 'Example']);
      expect(code, 0);

      expectAndroidScaffold(
        projectRoot: project.root,
        widgetClassName: 'ExampleHomeWidget',
      );
      expect(
        Directory(p.join(project.root.path, 'ios', 'ExampleHomeWidget'))
            .existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'create defaults to ios-only when only ios/ exists',
    () async {
      final project = await TestFlutterProject.create(includeAndroid: false);

      final code =
          await runCliWithProjectRoot(project.root, ['create', 'Example']);
      expect(code, 0);

      expectIosScaffold(
        projectRoot: project.root,
        widgetClassName: 'ExampleHomeWidget',
      );
      expect(
        Directory(p.join(project.root.path, 'android')).existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'create --android --ios creates android and warns when ios/ is missing',
    () async {
      final project = await TestFlutterProject.create(includeIos: false);

      final code = await runCliWithProjectRoot(
        project.root,
        ['create', '--android', '--ios', 'Example'],
      );
      expect(code, 0);

      expectAndroidScaffold(
        projectRoot: project.root,
        widgetClassName: 'ExampleHomeWidget',
      );
      verify(
        () => mockLogger.warn(
          any(
            that: contains(
              'Requested iOS scaffolding but no ios/ folder exists',
            ),
          ),
        ),
      ).called(1);
      expect(
        Directory(p.join(project.root.path, 'ios', 'ExampleHomeWidget'))
            .existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  group('stderr warnings for misconfigured projects', () {
    test(
      'warns when pubspec.yaml is missing (skips flutter pub add)',
      () async {
        final project = await TestFlutterProject.create(includeIos: false);
        final pubspec = File(p.join(project.root.path, 'pubspec.yaml'));
        expect(pubspec.existsSync(), isTrue);
        await pubspec.delete();

        final code = await runCliWithProjectRoot(
          project.root,
          ['create', '--android', 'Example'],
        );
        expect(code, 0);
        verify(
          () => mockLogger.warn(any(that: contains('pubspec.yaml not found'))),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'warns when android/app/ is missing (skips Android scaffolding)',
      () async {
        final project = await TestFlutterProject.create(includeIos: false);
        final androidAppDir =
            Directory(p.join(project.root.path, 'android', 'app'));
        expect(androidAppDir.existsSync(), isTrue);
        await androidAppDir.delete(recursive: true);

        final code = await runCliWithProjectRoot(
          project.root,
          ['create', '--android', 'Example'],
        );
        expect(code, 0);
        verify(
          () => mockLogger.warn(
            any(
              that: contains(
                'Warning: android/app/ not found. Skipping Android scaffolding.',
              ),
            ),
          ),
        ).called(1);

        // Ensure Android scaffolding truly did not run / recreate android/app/.
        expect(androidAppDir.existsSync(), isFalse);
        verifyNever(() => mockLogger.success(any(that: contains('Created:'))));
        verifyNever(() => mockLogger.detail(any(that: contains('Updated:'))));

        final androidDir = Directory(p.join(project.root.path, 'android'));
        final androidFiles = androidDir.existsSync()
            ? androidDir
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()
            : const <File>[];
        expect(
          androidFiles.any((f) {
            final base = p.basename(f.path);
            return base.contains('ExampleHomeWidget') ||
                base.contains('example_home_widget');
          }),
          isFalse,
          reason:
              'Expected no widget placeholder files to be created under android/',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'warns when AndroidManifest.xml is missing (skips manifest wiring)',
      () async {
        final project = await TestFlutterProject.create(includeIos: false);
        final manifest = File(
          p.join(
            project.root.path,
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          ),
        );
        expect(manifest.existsSync(), isTrue);
        await manifest.delete();

        final code = await runCliWithProjectRoot(
          project.root,
          ['create', '--android', 'Example'],
        );
        expect(code, 0);
        verify(
          () => mockLogger.warn(
            any(
              that: contains(
                'Warning: android/app/src/main/AndroidManifest.xml not found; skipping manifest wiring.',
              ),
            ),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'warns when AndroidManifest.xml cannot be parsed as XML',
      () async {
        final project = await TestFlutterProject.create(includeIos: false);
        final manifest = File(
          p.join(
            project.root.path,
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          ),
        );
        expect(manifest.existsSync(), isTrue);
        await manifest.writeAsString('not xml at all');

        final code = await runCliWithProjectRoot(
          project.root,
          ['create', '--android', 'Example'],
        );
        expect(code, 0);
        verify(
          () => mockLogger.warn(
            any(
              that: contains(
                'Warning: Could not parse AndroidManifest.xml as XML; skipping manifest wiring.',
              ),
            ),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'warns when android/app/build.gradle(.kts) is missing (skips Gradle setup)',
      () async {
        final project = await TestFlutterProject.create(includeIos: false);
        final appDir = Directory(p.join(project.root.path, 'android', 'app'));
        expect(appDir.existsSync(), isTrue);

        final groovy = File(p.join(appDir.path, 'build.gradle'));
        final kts = File(p.join(appDir.path, 'build.gradle.kts'));
        if (groovy.existsSync()) await groovy.delete();
        if (kts.existsSync()) await kts.delete();

        // Sanity: ensure both are gone.
        expect(groovy.existsSync(), isFalse);
        expect(kts.existsSync(), isFalse);

        final code = await runCliWithProjectRoot(
          project.root,
          ['create', '--android', 'Example'],
        );
        expect(code, 0);
        verify(
          () => mockLogger.warn(
            any(
              that: contains(
                'Warning: Could not find android/app/build.gradle(.kts); skipping Gradle Glance setup.',
              ),
            ),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  test(
    'create --ios produces a buildable iOS app (includes Widget Extension target)',
    () async {
      final project = await TestFlutterProject.create(includeAndroid: false);
      final code = await runCliWithProjectRoot(
        project.root,
        ['create', '--ios', 'Example'],
      );
      expect(code, 0);

      final widgetClassName = 'ExampleHomeWidget';
      expectIosScaffold(
        projectRoot: project.root,
        widgetClassName: widgetClassName,
      );

      final pbxproj = File(
        p.join(
          project.root.path,
          'ios',
          'Runner.xcodeproj',
          'project.pbxproj',
        ),
      );
      expect(pbxproj.existsSync(), isTrue);
      final pbxText = await pbxproj.readAsString();
      expect(pbxText, contains('name = $widgetClassName;'));
      expect(pbxText, contains('$widgetClassName.appex'));

      final build = await Process.run(
        'flutter',
        ['build', 'ios', '--no-codesign'],
        workingDirectory: project.root.path,
        runInShell: true,
      );
      expect(
        build.exitCode,
        0,
        reason:
            'flutter build ios failed.\nSTDOUT:\n${build.stdout}\n\nSTDERR:\n${build.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 25)),
    tags: ['integration', 'integration_ios'],
  );
}
