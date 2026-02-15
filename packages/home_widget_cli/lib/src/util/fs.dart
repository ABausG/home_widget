import 'dart:io';

import 'logger.dart';

/// Ensures a directory exists (creates it recursively if missing).
Future<void> ensureDir(Directory dir) async {
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
}

/// Writes [contents] to [file] only if the file does not already exist.
Future<void> writeFileIfMissing(File file, String contents) async {
  if (file.existsSync()) {
    logger.info('Skipping existing file: ${file.path}');
    return;
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
  logger.info('Created: ${file.path}');
}
