import 'dart:io';
import 'dart:isolate';

import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A temporary Flutter project created via `flutter create --empty --no-pub`
/// with only the requested `--platforms` (android / ios / web), then path deps
/// added via `dart pub add` (faster than `flutter pub add`).
///
/// The whole temp tree (`<systemTemp>/hw_cli_<random>/`, including `cli_test/`)
/// is deleted after the test completes via [addTearDown] registered in
/// [create]. Do not add a global [tearDownAll] that deletes paths from other
/// suites—parallel runs need each suite to only remove its own [tempDir].
final class TestFlutterProject {
  TestFlutterProject._(this.root);

  final Directory root;

  /// Adjusts the Android app's Gradle build script to use the requested DSL.
  ///
  /// This is intended for tests only. We only touch what's necessary for the CLI
  /// patchers (which edit `android/app/build.gradle(.kts)`).
  Future<void> setAndroidAppGradleDsl(AndroidAppGradleDsl dsl) async {
    final appDir = Directory(p.join(root.path, 'android', 'app'));
    if (!appDir.existsSync()) return;

    final groovy = File(p.join(appDir.path, 'build.gradle'));
    final kts = File(p.join(appDir.path, 'build.gradle.kts'));

    switch (dsl) {
      case AndroidAppGradleDsl.kts:
        // If the project already has KTS, do nothing. If it only has Groovy,
        // keep it as-is (tests can still cover the KTS path by using the default
        // template output on Flutter versions that generate .kts).
        return;
      case AndroidAppGradleDsl.groovy:
        // Prefer converting from an existing KTS file, but for tests it's enough
        // to ensure a valid Groovy file with the blocks our patchers need.
        if (kts.existsSync()) {
          await kts.delete();
        }

        if (groovy.existsSync()) return;

        await groovy.writeAsString(_minimalAndroidAppBuildGradleGroovy);
        return;
    }
  }

  static Future<TestFlutterProject> create({
    bool includeAndroid = true,
    bool includeIos = true,
  }) async {
    const projectDirName = 'cli_test';
    final tempDir = await Directory.systemTemp.createTemp('hw_cli_');

    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final platforms = <String>[
      if (includeAndroid) 'android',
      if (includeIos) 'ios',
      // If neither android nor ios is requested, create a minimal non-mobile
      // project to ensure the CLI sees "no android/ios folders" reliably.
      if (!includeAndroid && !includeIos) 'web',
    ];
    final platformArg = platforms.join(',');

    final result = await Process.run(
      'flutter',
      [
        '--suppress-analytics',
        'create',
        '--empty',
        '--no-pub',
        projectDirName,
        if (platformArg.isNotEmpty) '--platforms=$platformArg',
      ],
      workingDirectory: tempDir.path,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      // Retry with `--platform` if `--platforms` isn't supported in this Flutter.
      final retry = await Process.run(
        'flutter',
        [
          '--suppress-analytics',
          'create',
          '--empty',
          '--no-pub',
          projectDirName,
          if (platformArg.isNotEmpty) '--platform=$platformArg',
        ],
        workingDirectory: tempDir.path,
        runInShell: true,
      );
      if (retry.exitCode != 0) {
        throw StateError(
          'flutter create failed (exitCode ${retry.exitCode})\n'
          '${retry.stderr}\n'
          '${retry.stdout}',
        );
      }
    }

    final projectRoot = Directory(p.join(tempDir.path, projectDirName));
    if (!projectRoot.existsSync()) {
      throw StateError('Missing project dir: ${projectRoot.path}');
    }

    await _ensureHomeWidgetDependencyPresent(projectRoot);

    // home_widget requires iOS 14+; default `flutter create` templates may target lower.
    if (includeIos) {
      final pbxproj = File(
        p.join(projectRoot.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      );
      if (pbxproj.existsSync()) {
        await ensureMinimumDeploymentTargetInXcodeProject(pbxprojFile: pbxproj);
      }
    }

    return TestFlutterProject._(projectRoot);
  }
}

enum AndroidAppGradleDsl { kts, groovy }

// A minimal `android/app/build.gradle` that contains the blocks used by the CLI
// patchers:
// - `android { ... }` (for Compose enablement)
// - `dependencies { ... }` (for Glance dependency insertion)
const String _minimalAndroidAppBuildGradleGroovy = r'''
plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android"
}

android {
    buildFeatures {
    }
}

dependencies {
}
''';

Future<void> _ensureHomeWidgetDependencyPresent(Directory projectRoot) async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:home_widget_cli/src/cli.dart'),
  );
  if (packageUri == null) {
    throw StateError('Could not resolve package:home_widget_cli');
  }

  final cliPackageRoot = File(packageUri.toFilePath()).parent.parent.parent;
  final packagesDir = cliPackageRoot.parent;
  final homeWidgetPath = p.join(packagesDir.path, 'home_widget');
  final generatorPath = p.join(packagesDir.path, 'home_widget_generator');

  // Prefer `dart pub add`: lighter than `flutter pub add` (no Flutter tool boot).
  var result = await Process.run(
    'dart',
    ['pub', 'add', 'home_widget', '--path', homeWidgetPath],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw StateError('dart pub add home_widget failed:\n${result.stderr}');
  }

  // home_widget_generator declares a hosted home_widget constraint; in this
  // monorepo test harness both packages come from path (temp dirs need an
  // absolute override path).
  await File(p.join(projectRoot.path, 'pubspec_overrides.yaml')).writeAsString(
    'dependency_overrides:\n'
    '  home_widget:\n'
    '    path: $homeWidgetPath\n',
  );

  result = await Process.run(
    'dart',
    [
      'pub',
      'add',
      'home_widget_generator',
      '--dev',
      '--path',
      generatorPath,
    ],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'dart pub add home_widget_generator failed:\n${result.stderr}',
    );
  }
}
