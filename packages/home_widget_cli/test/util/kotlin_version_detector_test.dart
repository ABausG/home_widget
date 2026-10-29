import 'dart:io';

import 'package:home_widget_cli/src/util/kotlin_version_detector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/test_flutter_project.dart';

void main() {
  group('tryDetectAndroidKotlinVersion', () {
    // These are intentionally lightweight unit tests: we verify the text parsing
    // without requiring `flutter create` (which is slower and more environment-
    // dependent). We add one integration-ish test below to cover a real Flutter
    // project structure too.

    test('detects ext.kotlin_version in android/build.gradle', () async {
      final root = await Directory.systemTemp.createTemp('hw_kotlin_det_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      await Directory(p.join(root.path, 'android')).create(recursive: true);
      await File(p.join(root.path, 'android', 'build.gradle')).writeAsString(
        "buildscript { ext.kotlin_version = '1.9.22' }",
      );

      expect(tryDetectAndroidKotlinVersion(root), '1.9.22');
    });

    test('detects plugin DSL version in android/settings.gradle', () async {
      final root = await Directory.systemTemp.createTemp('hw_kotlin_det_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      await Directory(p.join(root.path, 'android')).create(recursive: true);
      await File(p.join(root.path, 'android', 'settings.gradle')).writeAsString(
        'plugins { id "org.jetbrains.kotlin.android" version "1.9.25" apply false }',
      );

      expect(tryDetectAndroidKotlinVersion(root), '1.9.25');
    });

    test('detects kotlin version in libs.versions.toml', () async {
      final root = await Directory.systemTemp.createTemp('hw_kotlin_det_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      await Directory(p.join(root.path, 'android', 'gradle'))
          .create(recursive: true);
      await File(p.join(root.path, 'android', 'gradle', 'libs.versions.toml'))
          .writeAsString('[versions]\nkotlin = "1.9.10"\n');

      expect(tryDetectAndroidKotlinVersion(root), '1.9.10');
    });

    test(
      'detects Kotlin version from a real Flutter project (smoke test)',
      () async {
        final project = await TestFlutterProject.create(includeIos: false);
        final v = tryDetectAndroidKotlinVersion(project.root);
        expect(v, isNotNull);
        expect(v, matches(RegExp(r'^\d+\.\d+\.\d+$')));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
