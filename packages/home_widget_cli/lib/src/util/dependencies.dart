import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli_io.dart';

/// Checks if `home_widget` is in `pubspec.yaml`, and if not, runs
/// `flutter pub add home_widget`.
Future<void> ensureFlutterHomeWidgetDependency(Directory projectRoot) async {
  final pubspec = File(p.join(projectRoot.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    cliIO.writelnErr(
      'Warning: pubspec.yaml not found in ${projectRoot.path}; skipping '
      '`flutter pub add home_widget`.',
    );
    return;
  }

  final text = await pubspec.readAsString();
  // Cheap idempotency: if the dependency is already present anywhere, skip.
  if (RegExp(r'^\s*home_widget\s*:', multiLine: true).hasMatch(text)) {
    return;
  }

  cliIO.writelnOut('Adding home_widget dependency...');
  final result = await Process.run(
    'flutter',
    ['pub', 'add', 'home_widget'],
    workingDirectory: projectRoot.path,
    runInShell: true,
  );

  if (result.stdout != null && result.stdout.toString().trim().isNotEmpty) {
    cliIO.writeOut(result.stdout.toString());
    if (!result.stdout.toString().endsWith('\n')) cliIO.writelnOut();
  }
  if (result.stderr != null && result.stderr.toString().trim().isNotEmpty) {
    cliIO.writeErr(result.stderr.toString());
    if (!result.stderr.toString().endsWith('\n')) cliIO.writelnErr();
  }

  if (result.exitCode != 0) {
    cliIO.writelnErr(
      'Warning: failed to run `flutter pub add home_widget` (exit code '
      '${result.exitCode}). You can run it manually in your project root.',
    );
  }
}
