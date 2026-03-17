import 'dart:io';

import 'package:home_widget_cli/src/cli.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/test_flutter_project.dart';

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
    logger = mockLogger;
  });

  tearDownAll(() {
    for (final root in createdTestProjectRoots) {
      final dir = Directory(root);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
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
        project.useAsCwd();

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
        final code = await runCli(
          ['generate', '--input', widgetFile.path, '--dart-out', dartOut],
        );
        expect(code, 0);

        verify(
          () => mockLogger.info(
            any(that: contains('Adding home_widget dependency...')),
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'skips adding home_widget dependency if already present',
      () async {
        final project = await TestFlutterProject.create();
        project.useAsCwd();

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
        final code = await runCli(
          ['generate', '--input', widgetFile.path, '--dart-out', dartOut],
        );
        expect(code, 0);

        verifyNever(
          () => mockLogger
              .info(any(that: contains('Adding home_widget dependency...'))),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'creates dart helper in lib/src/home_widget by default',
      () async {
        final project = await TestFlutterProject.create();
        project.useAsCwd();

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
        final code = await runCli(
          ['generate', '--input', widgetFile.path, '--dart-out', dartOutDir],
        );
        expect(code, 0);

        final expectedFile = p.join(dartOutDir, 'widget.home_widget.dart');
        expect(File(expectedFile).existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'generate produces a buildable app for Android and iOS',
      () async {
        // This is an end-to-end sanity check. It can be slow and requires a
        // macOS host with Xcode + CocoaPods for iOS.
        final shouldRun = Platform.isMacOS &&
            (Platform.environment['HW_CLI_IOS_BUILD_TESTS'] == '1' ||
                Platform.environment['CI'] == 'true');
        if (!shouldRun) {
          return;
        }

        Future<bool> hasTool(String tool, List<String> args) async {
          final r = await Process.run(tool, args, runInShell: true);
          return r.exitCode == 0;
        }

        if (!await hasTool('xcodebuild', ['-version'])) return;
        if (!await hasTool('pod', ['--version'])) return;

        final project = await TestFlutterProject.create();
        project.useAsCwd();

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
        final code = await runCli(['generate', '--dart-out', dartOut]);
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
    );
    test(
      'works with relative input path',
      () async {
        final project = await TestFlutterProject.create();
        project.useAsCwd();

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

        // Pass 'my_widgets' as a relative path
        // Since we did project.useAsCwd(), 'my_widgets' is relative to CWD.
        final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
        final code = await runCli(
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
        project.useAsCwd();

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

        final code = await runCli(
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
        project.useAsCwd();

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
        final code = await runCli(
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
        project.useAsCwd();

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

        final code = await runCli(
          ['generate', '--input', widgetFile.path, '--dart-out', 'out.txt'],
        );
        // Should fail due to invalid extension
        expect(code, isNot(0));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
