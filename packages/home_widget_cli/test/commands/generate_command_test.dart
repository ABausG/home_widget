import 'dart:io';

import 'package:home_widget_cli/src/cli.dart';
import 'package:home_widget_cli/src/util/exit_codes.dart';
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
    when(() => mockLogger.info(any())).thenAnswer((invocation) {
      print(invocation.positionalArguments.first);
    });
    when(() => mockLogger.err(any())).thenAnswer((invocation) {
      print(invocation.positionalArguments.first);
    });
    when(() => mockLogger.warn(any())).thenAnswer((invocation) {
      print(invocation.positionalArguments.first);
    });
    when(() => mockLogger.success(any())).thenAnswer((_) {});
    when(() => mockLogger.detail(any())).thenAnswer((_) {});
    when(() => mockLogger.progress(any())).thenReturn(FakeProgress());
    when(() => mockLogger.progress(any(), options: any(named: 'options')))
        .thenReturn(FakeProgress());
    logger = mockLogger;
  });

  group('GenerateCommand', () {
    test('fails if input path does not exist', () async {
      final code = await runCli(['generate', '--input', 'non_existent_path']);
      expect(code, isNot(0));
      verify(() => mockLogger.err(any(that: contains('does not exist'))))
          .called(1);
    });

    test(
      'adds home_widget dependency if missing during generation',
      () async {
        final project = await TestFlutterProject.create();
        // Create a dummy widget spec file
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'widget.dart'));
        widgetFile.createSync(recursive: true);
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        // Remove home_widget from pubspec to test addition
        final pubspec = File(p.join(project.root.path, 'pubspec.yaml'));
        var pubspecContent = pubspec.readAsStringSync();
        // Just in case the template included it (it usually doesn't in tests unless we add it)
        pubspecContent =
            pubspecContent.replaceAll('home_widget:', 'ignored_widget:');
        pubspec.writeAsStringSync(pubspecContent);

        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path, '--dart-out', dartOut],
        );
        expect(code, 0);

        verify(
          () => mockLogger.detail(
            any(that: contains('Adding home_widget dependency')),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'skips adding home_widget dependency if already present',
      () async {
        final project = await TestFlutterProject.create();
        // Create a dummy widget spec file
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'widget.dart'));
        widgetFile.createSync(recursive: true);
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        // Add home_widget to pubspec manually
        final pubspec = File(p.join(project.root.path, 'pubspec.yaml'));
        pubspec.writeAsStringSync(
          '\ndependencies:\n  home_widget: ^0.1.0\n',
          mode: FileMode.append,
        );

        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path, '--dart-out', dartOut],
        );
        expect(code, 0);

        verifyNever(
          () => mockLogger.detail(
            any(that: contains('Adding home_widget dependency')),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'creates dart helper in lib/src/home_widget by default',
      () async {
        final project = await TestFlutterProject.create();
        // Create a dummy widget spec file
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'widget.dart'));
        widgetFile.createSync(recursive: true);
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        final dartOutDir = p.join(
          project.root.path,
          'lib',
          'src',
          'home_widget',
        );
        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path, '--dart-out', dartOutDir],
        );
        expect(code, 0);

        verify(
          () => mockLogger.success(
            any(that: contains('Widgets generated successfully')),
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

        final expectedFile = p.join(dartOutDir, 'widget.home_widget.dart');
        expect(File(expectedFile).existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'generate produces a buildable app for Android and iOS',
      () async {
        final project = await TestFlutterProject.create();
        // Write the SimpleData schema file into the default input directory.
        final widgetDir = Directory(p.join(project.root.path, 'home_widget'));
        widgetDir.createSync(recursive: true);
        final schemaFile = File(p.join(widgetDir.path, 'simple_data.dart'));
        schemaFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Simple Data',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.example',
  ),
  data: {'label': HWString(), 'value': HWInt()},
)
class SimpleData {}
''');

        // Run the generate command.
        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--dart-out', dartOut],
        );
        expect(code, 0);

        // Build Android.
        final androidBuild = await Process.run(
          'flutter',
          ['build', 'apk'],
          workingDirectory: project.root.path,
          runInShell: true,
        );
        expect(
          androidBuild.exitCode,
          0,
          reason:
              'flutter build apk failed.\nSTDOUT:\n${androidBuild.stdout}\n\nSTDERR:\n${androidBuild.stderr}',
        );

        // Build iOS.
        final iosBuild = await Process.run(
          'flutter',
          ['build', 'ios', '--no-codesign'],
          workingDirectory: project.root.path,
          runInShell: true,
        );
        expect(
          iosBuild.exitCode,
          0,
          reason:
              'flutter build ios failed.\nSTDOUT:\n${iosBuild.stdout}\n\nSTDERR:\n${iosBuild.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 25)),
      tags: ['integration', 'integration_android', 'integration_ios'],
    );
    test(
      'warns when single input file has no HomeWidget annotation',
      () async {
        final project = await TestFlutterProject.create();
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'no_annotation.dart'));
        widgetFile.writeAsStringSync('class Plain {}');

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path],
        );
        expect(code, ExitCodes.success);
        verify(
          () => mockLogger.warn(
            any(that: contains('@HomeWidget')),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'returns software exit when schema validation fails',
      () async {
        final project = await TestFlutterProject.create();
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'bad_keys.dart'));
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Bad Keys',
  widget: HWText(HWString('class')),
)
class BadKeys {}
''');

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path],
        );
        expect(code, ExitCodes.software);
        verify(() => mockLogger.err(any())).called(greaterThanOrEqualTo(1));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'succeeds with no widgets when input directory is empty',
      () async {
        final project = await TestFlutterProject.create();
        final emptyDir = Directory(p.join(project.root.path, 'empty_in'));
        emptyDir.createSync();

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', emptyDir.path],
        );
        expect(code, ExitCodes.success);
        verify(
          () => mockLogger.info('No @HomeWidget annotated classes found.'),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'generates iOS only when android config omitted',
      () async {
        final project = await TestFlutterProject.create();
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'ios_only.dart'));
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Ios Only',
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
)
class IosOnly {}
''');

        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCliWithProjectRoot(
          project.root,
          [
            'generate',
            '--input',
            widgetFile.path,
            '--dart-out',
            dartOut,
          ],
        );
        expect(code, 0);
        verify(
          () => mockLogger.progress(
            any(that: contains('Generating Ios Only home_widget')),
          ),
        ).called(1);
        verifyNever(
          () => mockLogger.progress(
            any(that: contains('Generating Android widget')),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'generates Android and iOS when both configs are present',
      () async {
        final project = await TestFlutterProject.create();
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'both_platforms.dart'));
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Both Platforms',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
)
class BothPlatforms {}
''');

        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCliWithProjectRoot(
          project.root,
          [
            'generate',
            '--input',
            widgetFile.path,
            '--dart-out',
            dartOut,
          ],
        );
        expect(code, 0);
        verify(
          () => mockLogger.progress(
            any(that: contains('Generating Both Platforms home_widget')),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'uses dartOutput from annotation when --dart-out omitted',
      () async {
        final project = await TestFlutterProject.create();
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'with_dart_out.dart'));
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Dart Out',
  dartOutput: 'lib/foo.dart',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class WithDartOut {}
''');

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path],
        );
        expect(code, 0);
        final out = File(p.join(project.root.path, 'lib', 'foo.dart'));
        expect(out.existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'defaults dart helper path when neither dart-out nor dartOutput set',
      () async {
        final project = await TestFlutterProject.create();
        final widgetFile =
            File(p.join(project.root.path, 'lib', 'default_path.dart'));
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Default Path',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class DefaultPath {}
''');

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path],
        );
        expect(code, 0);
        final expected = p.join(
          project.root.path,
          'lib',
          'src',
          'home_widget',
          'default_path.home_widget.dart',
        );
        expect(File(expected).existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'works with relative input path',
      () async {
        final project = await TestFlutterProject.create();
        // Create a dummy widget spec file in a subdirectory
        final widgetDir = Directory(p.join(project.root.path, 'my_widgets'));
        widgetDir.createSync();
        final widgetFile = File(p.join(widgetDir.path, 'widget.dart'));
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        // Pass 'my_widgets' as a relative path (resolved vs project root via
        // runCliWithProjectRoot).
        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', 'my_widgets', '--dart-out', dartOut],
        );
        expect(code, 0);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('dart-out resolution', () {
    test(
      'accepts a directory and auto-generates filename',
      () async {
        final project = await TestFlutterProject.create();

        final widgetFile =
            File(p.join(project.root.path, 'lib', 'my_schema.dart'));
        widgetFile.createSync(recursive: true);
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        final outDir = p.join(project.root.path, 'generated');
        Directory(outDir).createSync();

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path, '--dart-out', outDir],
        );
        expect(code, 0);

        // Should auto-generate filename from schema file basename
        final expectedFile = p.join(outDir, 'my_schema.home_widget.dart');
        expect(File(expectedFile).existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'accepts an explicit .dart file path',
      () async {
        final project = await TestFlutterProject.create();

        final widgetFile =
            File(p.join(project.root.path, 'lib', 'widget.dart'));
        widgetFile.createSync(recursive: true);
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        final outFile =
            p.join(project.root.path, 'generated', 'custom_name.dart');
        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path, '--dart-out', outFile],
        );
        expect(code, 0);

        expect(File(outFile).existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'rejects invalid extension',
      () async {
        final project = await TestFlutterProject.create();

        final widgetFile =
            File(p.join(project.root.path, 'lib', 'widget.dart'));
        widgetFile.createSync(recursive: true);
        widgetFile.writeAsStringSync('''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'TestWidget',
  android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
)
class TestWidget {}
''');

        final code = await runCliWithProjectRoot(
          project.root,
          ['generate', '--input', widgetFile.path, '--dart-out', 'out.txt'],
        );
        // Should fail due to invalid extension
        expect(code, isNot(0));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
