import 'dart:io';

import 'logger.dart';

/// Ensures a directory exists (creates it recursively if missing).
Future<void> ensureDir(Directory dir) async {
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
}

/// Writes [bytes] to [file] unless it already holds exactly them.
///
/// Returns whether the file changed. Binary output is compared rather than
/// overwritten so that regenerating a project that did not change leaves every
/// copied font byte-identical, and with it its timestamp — a rewritten font
/// invalidates the incremental build of both platforms.
Future<bool> writeBytesIfChanged(File file, List<int> bytes) async {
  if (file.existsSync()) {
    final existing = await file.readAsBytes();
    if (existing.length == bytes.length) {
      var same = true;
      for (var i = 0; i < bytes.length; i++) {
        if (existing[i] != bytes[i]) {
          same = false;
          break;
        }
      }
      if (same) return false;
    }
  }
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return true;
}

/// Writes [contents] to [file] only if the file does not already exist.
Future<void> writeFileIfMissing(File file, String contents) async {
  if (file.existsSync()) {
    logger.detail('Skipping existing file: ${file.path}');
    return;
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
  logger.detail('Created: ${file.path}');
}
