import 'dart:io';

import 'package:home_widget_generator/home_widget_generator.dart';
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

  return _writeIconFonts(
    spec: spec,
    directory: fontDir,
    fonts: fonts,
    resourceName: (font) => font.androidResourceName(prefix),
    isOwned: (name) => name.startsWith('${prefix}__'),
  );
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
  return _writeIconFonts(
    spec: spec,
    directory: extensionDir,
    fonts: fonts,
    resourceName: (font) => font.iosResourceName,
    isOwned: (name) => name.startsWith('hw_font_$_iconResourceInfix'),
  );
}

/// What every icon font resource name carries between the widget's namespace
/// and the font itself, per `HWIconFont.resourceSuffix`.
const String _iconResourceInfix = 'icons_';

/// Copies the subset icon fonts of [spec] into [directory], naming each file
/// with [resourceName], then prunes the files [isOwned] claims that this run
/// did not just write.
Future<WrittenIconFonts> _writeIconFonts({
  required WidgetSpec spec,
  required Directory directory,
  required FontResolver fonts,
  required String Function(HWIconFont font) resourceName,
  required bool Function(String name) isOwned,
}) async {
  final written = <String>[];
  final namedBy = <String, HWIconFont>{};
  for (final entry in spec.iconCodePoints.entries) {
    final source = fonts.resolveIconFont(entry.key);
    final bytes = await fonts.subsetIconFont(source, entry.value);
    final name = '${resourceName(entry.key)}.${source.extension}';
    final clash = namedBy[name];
    if (clash != null) {
      throw GeneratorError(
        'The icon fonts ${_describe(clash)} and ${_describe(entry.key)} of '
        'widget "${spec.data.name}" both write "$name". Rename one of the '
        'families so each icon font gets a file of its own.',
      );
    }
    namedBy[name] = entry.key;
    final file = File(p.join(directory.path, name));
    if (await writeBytesIfChanged(file, bytes)) {
      logger.detail('Generated: ${file.path}');
    }
    written.add(name);
  }

  final removed = await _prune(
    directory: directory,
    keep: written.toSet(),
    isOwned: isOwned,
  );
  return WrittenIconFonts(written: written, removed: removed);
}

String _describe(HWIconFont font) => font.package == null
    ? '"${font.family}"'
    : '"${font.family}" of package "${font.package}"';

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
