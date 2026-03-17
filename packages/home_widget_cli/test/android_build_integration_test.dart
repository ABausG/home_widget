import 'dart:io';
import 'package:home_widget_cli/src/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/test_flutter_project.dart';

void main() {
  test(
    'generates and builds android app with simple color widget',
    () async {
      final project = await TestFlutterProject.create(includeIos: false);

      final widgetDir = Directory(p.join(project.root.path, 'home_widget'));
      widgetDir.createSync(recursive: true);
      final widgetFile = File(p.join(widgetDir.path, 'widget.dart'));
      await widgetFile.writeAsString('''
import 'package:home_widget_generator/home_widget_generator.dart';

import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Simple Color',
  android: HomeWidgetAndroidConfiguration(),
  widget: HWFill(
    child: HWColoredBox(
      color: HWColor.fixed(0xFF0000FF),
      child: HWFill(
        child: HWColumn(
          children: [
            HWText.fixed('No Color'),
            HWText.fixed(
              'Fixed Color',
              style: HWTextStyle(color: HWFixedColor(0xFFFF0000)),
            ),
            HWText.fixed(
              'Themed',
              style: HWTextStyle(
                color: HWThemedColor(
                  light: HWFixedColor(0xFFFFF00),
                  dark: HWFixedColor(0xFF00FFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
)
class SimpleColor {}
''');

      // Run the CLI programmatically to ensure the current source is used and not a cached pub version
      project.useAsCwd();
      final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
      final cliResult = await runCli(
        ['generate', '--input', widgetFile.path, '--dart-out', dartOut],
      );

      if (cliResult != 0) {
        fail('CLI failed with exit code $cliResult');
      }

      final kotlinFilePath = p.join(
        project.root.path,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        'com',
        'example',
        'cli_test',
        'SimpleColorHomeWidget.kt',
      );
      expect(
        File(kotlinFilePath).existsSync(),
        isTrue,
        reason: 'CLI should have generated the HomeWidget Kotlin classes',
      );

      // Now run flutter build to check if it compiles Kotlin code cleanly
      final buildResult = await Process.run(
        'flutter',
        ['build', 'apk'],
        workingDirectory: project.root.path,
      );

      if (buildResult.exitCode != 0) {
        fail(
          'Flutter build failed:\\n${buildResult.stdout}\\n${buildResult.stderr}\\nKotlin generated:\\n${File(p.join(project.root.path, 'android', 'app', 'src', 'main', 'kotlin', 'com', 'example', 'cli_test', 'SimpleColorHomeWidget.kt')).readAsStringSync()}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    tags: ['integration', 'integration_android'],
  );
}
