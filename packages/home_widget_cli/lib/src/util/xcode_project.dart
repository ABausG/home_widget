import 'dart:io';

import 'package:path/path.dart' as p;

import '../generator_error.dart';

/// The `project.pbxproj` of the app's Xcode project in [iosDir].
///
/// Like Flutter, this takes the project from the non-hidden `*.xcodeproj`
/// directory in `ios/` rather than requiring the name `flutter create` gives
/// it; only directories holding a `project.pbxproj` count. When there are
/// several, `Runner.xcodeproj` is the app's.
///
/// Throws a [GeneratorError] when [iosDir] holds no Xcode project, or several
/// of which none is `Runner.xcodeproj`.
File findXcodeProject(Directory iosDir) {
  final candidates = [
    for (final entity in iosDir.listSync())
      if (entity is Directory &&
          p.extension(entity.path) == '.xcodeproj' &&
          !p.basename(entity.path).startsWith('.') &&
          File(p.join(entity.path, 'project.pbxproj')).existsSync())
        p.basename(entity.path),
  ]..sort();

  final name = candidates.contains('Runner.xcodeproj')
      ? 'Runner.xcodeproj'
      : candidates.length == 1
          ? candidates.single
          : null;
  if (name != null) return File(p.join(iosDir.path, name, 'project.pbxproj'));

  if (candidates.isEmpty) {
    throw GeneratorError(
      'No Xcode project found in ${iosDir.path}. home_widget adds the widget '
      "extension to the app's Xcode project: a .xcodeproj folder in ios/ "
      'holding a project.pbxproj, ios/Runner.xcodeproj in a project made by '
      '`flutter create`.',
    );
  }
  throw GeneratorError(
    '${iosDir.path} holds several Xcode projects '
    '(${candidates.join(', ')}) and none is Runner.xcodeproj, so home_widget '
    "cannot tell which one is the app's. Keep only the app's Xcode project in "
    'ios/, or name it Runner.xcodeproj.',
  );
}

/// The name of the Xcode project [pbxprojFile] belongs to, `MyApp` for
/// `MyApp.xcodeproj/project.pbxproj`, or `null` when it is not inside an
/// `.xcodeproj` directory.
String? xcodeProjectName(File pbxprojFile) {
  final directory = pbxprojFile.parent.path;
  return p.extension(directory) == '.xcodeproj'
      ? p.basenameWithoutExtension(directory)
      : null;
}
