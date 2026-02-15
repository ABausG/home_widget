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

        final code = await runCli(['generate', '--input', widgetFile.path]);
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

        final code = await runCli(['generate', '--input', widgetFile.path]);
        expect(code, 0);

        verifyNever(
          () => mockLogger
              .info(any(that: contains('Adding home_widget dependency...'))),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
