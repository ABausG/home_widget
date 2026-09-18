import 'dart:io';

import 'package:path/path.dart' as p;

/// The build settings an `.xcconfig` file defines, includes resolved.
///
/// `#include "rel/path"` and `#include? "rel/path"` are followed relative to
/// the including file. A file that does not exist contributes nothing:
/// `Generated.xcconfig` and the CocoaPods files are written by the first build,
/// and a project has to be readable before it has ever been built.
///
/// Assignment order is Xcode's: a later line wins, so settings written after an
/// include override what the include brought in. Conditional assignments
/// (`KEY[sdk=iphoneos*] = …`) are ignored — they apply to a subset of builds
/// and the unconditional value is the one that describes the configuration.
///
/// A value that is a single quoted string loses its quotes, so it reads the
/// same as the value a `project.pbxproj` spells with quotes.
Map<String, String> readXcconfigSettings(File file) {
  final settings = <String, String>{};
  _readInto(file, settings, <String>{});
  return settings;
}

final RegExp _includeRe = RegExp(r'^\s*#include\??\s+"([^"]+)"');
final RegExp _settingRe = RegExp(
  r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(\[[^\]]*\])?\s*=(.*)$',
);

void _readInto(File file, Map<String, String> into, Set<String> visited) {
  final canonical = p.canonicalize(file.path);
  if (!visited.add(canonical)) return;
  if (!file.existsSync()) return;

  String content;
  try {
    content = file.readAsStringSync();
  } on FileSystemException {
    return;
  }

  for (final rawLine in content.split('\n')) {
    final line = _stripComment(rawLine);
    if (line.trim().isEmpty) continue;

    final include = _includeRe.firstMatch(line);
    if (include != null) {
      _readInto(
        File(p.normalize(p.join(file.parent.path, include.group(1)!))),
        into,
        visited,
      );
      continue;
    }

    final setting = _settingRe.firstMatch(line);
    if (setting == null || setting.group(2) != null) continue;
    into[setting.group(1)!] = _unquote(setting.group(3)!.trim());
  }
}

String _unquote(String value) =>
    RegExp(r'^"([^"]*)"$').firstMatch(value)?.group(1) ?? value;

String _stripComment(String line) {
  final idx = line.indexOf('//');
  return idx == -1 ? line : line.substring(0, idx);
}
