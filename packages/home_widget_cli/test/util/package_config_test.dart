import 'dart:io';

import 'package:home_widget_cli/src/util/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hw_package_config');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('readFlutterSection', () {
    test('reads the flutter section of a pubspec', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: app

flutter:
  uses-material-design: true
''');

      expect(readFlutterSection(tempDir.path)?['uses-material-design'], isTrue);
    });

    test('is null without a pubspec', () {
      expect(readFlutterSection(tempDir.path), isNull);
    });

    test('is null for a pubspec that does not parse', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: app

flutter: [
''');

      expect(readFlutterSection(tempDir.path), isNull);
    });

    test('is null for a pubspec without a flutter map', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: app');

      expect(readFlutterSection(tempDir.path), isNull);
    });
  });
}
