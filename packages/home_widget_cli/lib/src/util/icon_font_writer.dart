import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import 'font_resolver.dart';
import 'fs.dart';
import 'logger.dart';

/// The icon font files one widget owns on one platform, after a generate run.
class WrittenIconFonts {
  /// The file names, extension included, that now exist.
  final List<String> written;

  /// The file names this run deleted because the widget no longer draws out of
  /// them.
  final List<String> removed;

  /// Creates a [WrittenIconFonts].
  const WrittenIconFonts({required this.written, required this.removed});
}

/// Copies the subset icon fonts of [spec] into `android/app/src/main/res/font`.
///
/// Every file is named after the widget, so one widget's fonts never collide
/// with another's in Android's flat resource table — and so the ones this run
/// did not produce can be recognized as this widget's leftovers and deleted.
Future<WrittenIconFonts> writeAndroidIconFonts({
  required WidgetSpec spec,
  required Directory projectRoot,
  required FontResolver fonts,
}) async {
  final fontDir = Directory(
    p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res', 'font'),
  );
  final prefix = spec.fontResourcePrefix;

  final written = <String>[];
  for (final entry in spec.iconCodePoints.entries) {
    final source = fonts.resolveIconFont(entry.key);
    final bytes = await fonts.subsetIconFont(source, entry.value);
    final name = '${entry.key.androidResourceName(prefix)}.${source.extension}';
    final file = File(p.join(fontDir.path, name));
    if (await writeBytesIfChanged(file, bytes)) {
      logger.detail('Generated: ${file.path}');
    }
    written.add(name);
  }

  // `_icons_` is part of the claim, not decoration: without it a widget named
  // `Mood` would own — and delete — the fonts of one named `MoodBoard`.
  final removed = await _prune(
    directory: fontDir,
    keep: written.toSet(),
    isOwned: (name) => name.startsWith('${prefix}_$_iconResourceInfix'),
  );
  return WrittenIconFonts(written: written, removed: removed);
}

/// Copies the subset icon fonts of [spec] into the widget's iOS extension
/// folder.
///
/// The extension is its own bundle, so the widget's name is not part of the file
/// name and every `hw_font_icons_` file in the folder belongs to this widget.
Future<WrittenIconFonts> writeIosIconFonts({
  required WidgetSpec spec,
  required Directory extensionDir,
  required FontResolver fonts,
}) async {
  final written = <String>[];
  for (final entry in spec.iconCodePoints.entries) {
    final source = fonts.resolveIconFont(entry.key);
    final bytes = await fonts.subsetIconFont(source, entry.value);
    final name = '${entry.key.iosResourceName}.${source.extension}';
    final file = File(p.join(extensionDir.path, name));
    if (await writeBytesIfChanged(file, bytes)) {
      logger.detail('Generated: ${file.path}');
    }
    written.add(name);
  }

  final removed = await _prune(
    directory: extensionDir,
    keep: written.toSet(),
    isOwned: (name) => name.startsWith('hw_font_$_iconResourceInfix'),
  );
  return WrittenIconFonts(written: written, removed: removed);
}

/// What every icon font resource name carries between the widget's namespace
/// and the font itself, per `HWIconFont.resourceSuffix`.
const String _iconResourceInfix = 'icons_';

/// Deletes the files of [directory] that [isOwned] claims and [keep] does not
/// list.
Future<List<String>> _prune({
  required Directory directory,
  required Set<String> keep,
  required bool Function(String name) isOwned,
}) async {
  if (!directory.existsSync()) return const [];

  final removed = <String>[];
  for (final entity in directory.listSync().whereType<File>()) {
    final name = p.basename(entity.path);
    if (!isOwned(name) || keep.contains(name)) continue;
    await entity.delete();
    logger.detail('Removed stale: ${entity.path}');
    removed.add(name);
  }
  removed.sort();
  return removed;
}
