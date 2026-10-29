import 'dart:io';

import 'package:home_widget_cli/src/cli.dart';

/// Test-only: run the CLI with [Directory.current] set to [projectRoot] for
/// the duration of the call. Restores the previous working directory in a
/// `finally` block.
///
/// If the saved cwd no longer exists (e.g. another test's teardown deleted a
/// temp tree while suites run concurrently), falls back to [Directory.systemTemp]
/// so the next test does not inherit a dead path.
Future<int> runCliWithProjectRoot(
  Directory projectRoot,
  List<String> args,
) async {
  if (!projectRoot.existsSync()) {
    throw StateError(
      'runCliWithProjectRoot: project root does not exist: ${projectRoot.path}',
    );
  }

  final savedPath = Directory.current.path;
  Directory.current = projectRoot;
  try {
    return await runCli(args);
  } finally {
    _restoreOrFallback(savedPath);
  }
}

void _restoreOrFallback(String savedPath) {
  try {
    final saved = Directory(savedPath);
    if (saved.existsSync()) {
      Directory.current = saved;
      return;
    }
  } on FileSystemException {
    // Fall through to fallback.
  }
  Directory.current = Directory.systemTemp;
}
