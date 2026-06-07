import 'dart:io';

import 'package:path/path.dart' as p;

import 'logger.dart';

/// Checks if `home_widget` is in `pubspec.yaml`, and if not, runs
/// `flutter pub add home_widget:^0.9.2`.
Future<void> ensureFlutterHomeWidgetDependency(Directory projectRoot) async {
  final pubspec = File(p.join(projectRoot.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    logger.warn(
      'pubspec.yaml not found in ${projectRoot.path}; skipping '
      '`flutter pub add home_widget`.',
    );
    return;
  }

  final text = await pubspec.readAsString();
  // Cheap idempotency: if the dependency is already present anywhere, skip.
  if (RegExp(r'^\s*home_widget\s*:', multiLine: true).hasMatch(text)) {
    return;
  }

  logger.detail('Adding home_widget dependency');
  final result = await Process.run(
    'flutter',
    ['pub', 'add', 'home_widget:^0.9.2'],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );

  if (result.stdout != null && result.stdout.toString().trim().isNotEmpty) {
    // coverage:ignore-start
    logger.detail(result.stdout.toString());
    // coverage:ignore-end
  }
  if (result.stderr != null && result.stderr.toString().trim().isNotEmpty) {
    logger.err(result.stderr.toString());
  }

  if (result.exitCode != 0) {
    logger.alert(
      'Warning: failed to run `flutter pub add home_widget` (exit code '
      '${result.exitCode}). You can run it manually in your project root.',
    );
  }
}
