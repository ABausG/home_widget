import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// The `home_widget_cli` package directory, wherever the test process runs
/// from.
Future<Directory> cliPackageRoot() async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:home_widget_cli/src/cli.dart'),
  );
  if (packageUri == null) {
    throw StateError('Could not resolve package:home_widget_cli');
  }
  return File(packageUri.toFilePath()).parent.parent.parent;
}

/// The directory holding the `project.pbxproj` fixtures.
Future<Directory> pbxprojFixturesDirectory() async => Directory(
      p.join((await cliPackageRoot()).path, 'test', 'fixtures', 'pbxproj'),
    );
