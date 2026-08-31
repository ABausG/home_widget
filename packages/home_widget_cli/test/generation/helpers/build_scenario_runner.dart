import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../helpers/run_cli_in_project.dart';
import '../../helpers/test_flutter_project.dart';
import '../scenarios/build_scenario.dart';

/// Generates the widget code for [scenario] inside a fresh Android-only
/// Flutter project, then runs `flutter build apk` to ensure the generated
/// Kotlin compiles cleanly.
Future<void> runAndroidBuildScenario(BuildScenario scenario) async {
  final project = await TestFlutterProject.create(includeIos: false);
  await _generate(project, scenario);

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
    '${scenario.className}HomeWidget.kt',
  );
  expect(
    File(kotlinFilePath).existsSync(),
    isTrue,
    reason: 'CLI should have generated the HomeWidget Kotlin classes',
  );

  final appManifest = File(
    p.join(
      project.root.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  final appManifestSource = appManifest.readAsStringSync();

  if (scenario.expectsScheduledUpdateWiring) {
    expect(
      appManifestSource,
      contains(
        'es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver',
      ),
      reason: 'CLI should register the scheduled update receiver for specs '
          'with time-based fields',
    );
    expect(
      appManifestSource,
      contains('android.permission.RECEIVE_BOOT_COMPLETED'),
      reason: 'CLI should declare the boot permission for specs with '
          'time-based fields',
    );
  } else {
    expect(
      appManifestSource,
      isNot(contains('HomeWidgetScheduledUpdateReceiver')),
      reason: 'Specs without time-based fields must not gain scheduling '
          'manifest entries',
    );
  }

  final buildResult = await Process.run(
    'flutter',
    ['build', 'apk'],
    workingDirectory: project.root.path,
  );

  if (buildResult.exitCode != 0) {
    fail(
      'Flutter build failed:\n${buildResult.stdout}\n${buildResult.stderr}\n'
      'Kotlin generated:\n${File(kotlinFilePath).readAsStringSync()}',
    );
  }

  if (scenario.expectsScheduledUpdateWiring) {
    _expectReceiverInMergedManifest(project.root);
  }
}

/// Asserts the scheduling receiver survived AGP's manifest merge.
///
/// Flutter redirects the Gradle build directory to `<project>/build/app`, and
/// the exact intermediates layout below it depends on the Android Gradle Plugin
/// version, so the merged manifests are discovered rather than hard-coded.
void _expectReceiverInMergedManifest(Directory projectRoot) {
  final searchRoots = [
    Directory(p.join(projectRoot.path, 'build', 'app', 'intermediates')),
    Directory(
      p.join(projectRoot.path, 'android', 'app', 'build', 'intermediates'),
    ),
  ].where((d) => d.existsSync());

  final merged = [
    for (final root in searchRoots)
      ...root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => p.basename(f.path) == 'AndroidManifest.xml')
          .where((f) => f.path.contains('merged_manifest')),
  ];

  expect(
    merged,
    isNotEmpty,
    reason: 'Expected AGP to have produced at least one merged manifest under '
        '${searchRoots.map((d) => d.path).join(', ')}',
  );

  const receiverFqcn =
      'es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver';
  expect(
    merged.any((f) => f.readAsStringSync().contains(receiverFqcn)),
    isTrue,
    reason: 'Merged manifest should contain the scheduled update receiver. '
        'Checked: ${merged.map((f) => f.path).join(', ')}',
  );
}

/// Generates the widget code for [scenario] inside a fresh iOS-only Flutter
/// project, then runs `flutter build ios --no-codesign` to ensure the
/// generated Swift compiles cleanly.
Future<void> runIosBuildScenario(BuildScenario scenario) async {
  final project = await TestFlutterProject.create(includeAndroid: false);
  await _generate(project, scenario);

  final swiftFilePath = p.join(
    project.root.path,
    'ios',
    '${scenario.className}HomeWidget',
    'Widget.swift',
  );
  expect(
    File(swiftFilePath).existsSync(),
    isTrue,
    reason: 'CLI should have generated the HomeWidget Swift sources',
  );

  final buildResult = await Process.run(
    'flutter',
    ['build', 'ios', '--no-codesign'],
    workingDirectory: project.root.path,
  );

  if (buildResult.exitCode != 0) {
    fail(
      'Flutter build failed:\n${buildResult.stdout}\n${buildResult.stderr}\n'
      'Swift generated:\n${File(swiftFilePath).readAsStringSync()}',
    );
  }
}

Future<void> _generate(
  TestFlutterProject project,
  BuildScenario scenario,
) async {
  final widgetDir = Directory(p.join(project.root.path, 'home_widget'));
  widgetDir.createSync(recursive: true);
  final widgetFile = File(p.join(widgetDir.path, 'widget.dart'));
  await widgetFile.writeAsString(scenario.widgetSource);

  final dartOut = p.join(project.root.path, 'lib', 'src', 'home_widget');
  final cliResult = await runCliWithProjectRoot(
    project.root,
    ['generate', '--input', widgetFile.path, '--dart-out', dartOut],
  );

  if (cliResult != 0) {
    fail('CLI failed with exit code $cliResult');
  }
}
