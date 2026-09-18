import 'dart:io';

import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/util/xcode_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory iosDir;

  setUp(() {
    final root = Directory.systemTemp.createTempSync('hw_xcode_project');
    addTearDown(() => root.deleteSync(recursive: true));
    iosDir = Directory(p.join(root.path, 'ios'))..createSync();
  });

  void project(String name) =>
      File(p.join(iosDir.path, name, 'project.pbxproj'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{}');

  String found() =>
      p.relative(findXcodeProject(iosDir).path, from: iosDir.path);

  group('findXcodeProject', () {
    test('finds Runner.xcodeproj', () {
      project('Runner.xcodeproj');

      expect(found(), p.join('Runner.xcodeproj', 'project.pbxproj'));
    });

    test('finds a project of another name when it is the only one', () {
      project('MyApp.xcodeproj');

      expect(found(), p.join('MyApp.xcodeproj', 'project.pbxproj'));
    });

    test('prefers Runner.xcodeproj when there are several', () {
      project('Another.xcodeproj');
      project('Runner.xcodeproj');
      project('Zeta.xcodeproj');

      expect(found(), p.join('Runner.xcodeproj', 'project.pbxproj'));
    });

    test('fails naming every project when none is Runner.xcodeproj', () {
      project('Zeta.xcodeproj');
      project('MyApp.xcodeproj');

      expect(
        () => findXcodeProject(iosDir),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            startsWith(
              '${iosDir.path} holds several Xcode projects '
              '(MyApp.xcodeproj, Zeta.xcodeproj) and none is Runner.xcodeproj',
            ),
          ),
        ),
      );
    });

    test('ignores a hidden project', () {
      project('.Backup.xcodeproj');
      project('MyApp.xcodeproj');

      expect(found(), p.join('MyApp.xcodeproj', 'project.pbxproj'));
    });

    test('ignores a project directory without a project.pbxproj', () {
      Directory(p.join(iosDir.path, 'Runner.xcodeproj')).createSync();
      project('MyApp.xcodeproj');

      expect(found(), p.join('MyApp.xcodeproj', 'project.pbxproj'));
    });

    test('fails when ios/ holds no Xcode project', () {
      project('.Hidden.xcodeproj');
      Directory(p.join(iosDir.path, 'Empty.xcodeproj')).createSync();
      File(p.join(iosDir.path, 'Stray.xcodeproj')).writeAsStringSync('');
      project('Runner');

      expect(
        () => findXcodeProject(iosDir),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith('No Xcode project found in ${iosDir.path}. '),
              contains('ios/Runner.xcodeproj'),
            ),
          ),
        ),
      );
    });
  });

  group('xcodeProjectName', () {
    test('is the name of the .xcodeproj holding the file', () {
      expect(
        xcodeProjectName(
          File(p.join('ios', 'MyApp.xcodeproj', 'project.pbxproj')),
        ),
        'MyApp',
      );
    });

    test('is null for a file outside a .xcodeproj', () {
      expect(xcodeProjectName(File(p.join('tmp', 'project.pbxproj'))), isNull);
    });
  });
}
