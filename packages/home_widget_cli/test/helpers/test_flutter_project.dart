import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Tracks temp project roots so test suites can assert cleanup happened.
final List<String> createdTestProjectRoots = <String>[];

/// A temporary Flutter project created via `flutter create --empty cli_test`.
///
/// The project directory is deleted automatically via `addTearDown`.
final class TestFlutterProject {
  TestFlutterProject._(this.root) {
    createdTestProjectRoots.add(root.path);
  }

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
      // Prefer `--platforms` (current Flutter), but allow fallback to `--platform`
      // since some setups/scripts use that spelling.
      [
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
          'create',
          '--empty',
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
    return TestFlutterProject._(projectRoot);
  }

  /// Switches `Directory.current` to this Flutter project root and restores it
  /// automatically via `addTearDown`.
  void useAsCwd() {
    final previous = Directory.current;
    Directory.current = root;
    addTearDown(() {
      Directory.current = previous;
    });
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
  // Assume we are running from packages/home_widget_cli
  final cliPackageRoot = Directory.current;
  final packagesDir = cliPackageRoot.parent;
  final homeWidgetPath = p.join(packagesDir.path, 'home_widget');
  final generatorPath = p.join(packagesDir.path, 'home_widget_generator');

  // Add home_widget dependency
  var result = await Process.run(
    'flutter',
    ['pub', 'add', 'home_widget', '--path', homeWidgetPath],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw StateError('flutter pub add home_widget failed:\n${result.stderr}');
  }

  // Add home_widget_generator dev dependency
  result = await Process.run(
    'flutter',
    ['pub', 'add', 'home_widget_generator', '--dev', '--path', generatorPath],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'flutter pub add home_widget_generator failed:\n${result.stderr}',
    );
  }
}
