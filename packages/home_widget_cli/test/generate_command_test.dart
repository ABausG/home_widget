import 'dart:io';

import 'package:home_widget_cli/src/cli.dart';
import 'package:home_widget_cli/src/util/cli_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/test_flutter_project.dart';

void main() {
  tearDownAll(() {
    for (final root in createdTestProjectRoots) {
      final dir = Directory(root);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  });

  ({StringBuffer out, StringBuffer err}) captureCliOutput() {
    final out = StringBuffer();
    final err = StringBuffer();
    cliIO = CliIO(out: out.write, err: err.write);
    addTearDown(resetCliIO);
    return (out: out, err: err);
  }

  group('GenerateCommand', () {
    test('fails if input path does not exist', () async {
      final code = await runCli(['generate', '--input', 'non_existent_path']);
      expect(code, isNot(0));
    });

    test(
      'adds home_widget dependency if missing during generation',
      () async {
        final capture = captureCliOutput();
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

        expect(
          capture.out.toString(),
          contains('Adding home_widget dependency...'),
        );
        // Note: The actual `flutter pub add` might fail in this test environment if internet
        // is restricted or if the package doesn't resolve, but we check that the CLI *attempted* it.
        // If the command fails, it logs to stderr, but the generate command usually returns success (0)
        // because dependency addition is a "best effort" post-step or warning.
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'skips adding home_widget dependency if already present',
      () async {
        final capture = captureCliOutput();
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
        pubspec.writeAsStringSync('\ndependencies:\n  home_widget: ^0.1.0\n',
            mode: FileMode.append);

        final code = await runCli(['generate', '--input', widgetFile.path]);
        expect(code, 0);

        expect(
          capture.out.toString(),
          isNot(contains('Adding home_widget dependency...')),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
