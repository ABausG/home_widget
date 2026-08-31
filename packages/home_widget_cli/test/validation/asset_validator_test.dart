import 'dart:io';

import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/asset_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory projectRoot;

  setUp(() {
    projectRoot = Directory.systemTemp.createTempSync('hw_assets_');
  });

  tearDown(() {
    if (projectRoot.existsSync()) {
      projectRoot.deleteSync(recursive: true);
    }
  });

  /// Writes a file (with parents) at a project-relative [relativePath].
  void writeProjectFile(String relativePath, String contents) {
    final file =
        File(p.join(projectRoot.path, p.joinAll(relativePath.split('/'))));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  /// Writes a pubspec declaring [assets] under `flutter: assets:`.
  void writePubspec(List<String> assets) {
    final buffer = StringBuffer('name: cli_test\n\nflutter:\n');
    if (assets.isNotEmpty) {
      buffer.writeln('  assets:');
      for (final asset in assets) {
        buffer.writeln('    - $asset');
      }
    } else {
      buffer.writeln('  uses-material-design: true');
    }
    writeProjectFile('pubspec.yaml', buffer.toString());
  }

  /// Writes a package_config.json mapping [packageName] to [packageDir].
  void writePackageConfig(String packageName, Directory packageDir) {
    writeProjectFile(
      '.dart_tool/package_config.json',
      '{\n'
          '  "configVersion": 2,\n'
          '  "packages": [\n'
          '    {\n'
          '      "name": "$packageName",\n'
          '      "rootUri": "${Uri.file(packageDir.path)}",\n'
          '      "packageUri": "lib/",\n'
          '      "languageVersion": "3.5"\n'
          '    }\n'
          '  ]\n'
          '}\n',
    );
  }

  WidgetSpec specWith(List<HWDataType<dynamic>> fields) => WidgetSpec(
        data: HomeWidget(name: 'Test Widget'),
        className: 'TestWidget',
        dataFields: fields,
      );

  group('validateAssets', () {
    test('accepts an existing asset declared as a file entry', () {
      writeProjectFile('assets/logo.png', 'png');
      writePubspec(['assets/logo.png']);

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/logo.png')]),
          projectRoot,
        ),
        returnsNormally,
      );
    });

    test('accepts an asset covered by a directory entry', () {
      writeProjectFile('assets/logo.png', 'png');
      writePubspec(['assets/']);

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/logo.png')]),
          projectRoot,
        ),
        returnsNormally,
      );
    });

    test('accepts the map form of an asset entry', () {
      writeProjectFile('assets/logo.png', 'png');
      writeProjectFile(
        'pubspec.yaml',
        'name: cli_test\n'
            '\n'
            'flutter:\n'
            '  assets:\n'
            '    - path: assets/logo.png\n'
            '      flavors:\n'
            '        - free\n',
      );

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/logo.png')]),
          projectRoot,
        ),
        returnsNormally,
      );
    });

    test('rejects a subdirectory not covered by its parent directory entry',
        () {
      writeProjectFile('assets/icons/logo.png', 'png');
      writePubspec(['assets/']);

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/icons/logo.png')]),
          projectRoot,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Undeclared asset'),
              contains('TestWidget'),
              contains('assets/icons/logo.png'),
            ),
          ),
        ),
      );
    });

    test('rejects a missing file', () {
      writePubspec(['assets/logo.png']);

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/logo.png')]),
          projectRoot,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Missing asset'),
              contains('TestWidget'),
              contains('assets/logo.png'),
            ),
          ),
        ),
      );
    });

    test('rejects an existing but undeclared asset', () {
      writeProjectFile('assets/logo.png', 'png');
      writePubspec(const []);

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/logo.png')]),
          projectRoot,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('Undeclared asset'),
          ),
        ),
      );
    });

    test('reports undeclared when pubspec.yaml is missing entirely', () {
      writeProjectFile('assets/logo.png', 'png');

      expect(
        () => validateAssets(
          specWith(const [HWImageData.asset('assets/logo.png')]),
          projectRoot,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('Undeclared asset'),
          ),
        ),
      );
    });

    test('never validates runtime images', () {
      // No pubspec, no files: a runtime image must still pass.
      expect(
        () => validateAssets(
          specWith(const [HWImageData('avatar')]),
          projectRoot,
        ),
        returnsNormally,
      );
    });

    group('package assets', () {
      late Directory packageDir;

      setUp(() {
        packageDir = Directory.systemTemp.createTempSync('hw_pkg_');
      });

      tearDown(() {
        if (packageDir.existsSync()) {
          packageDir.deleteSync(recursive: true);
        }
      });

      void writePackageAsset(String relativePath) {
        final file = File(
          p.join(packageDir.path, 'lib', p.joinAll(relativePath.split('/'))),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('png');
      }

      test('accepts a resolvable packages/ path', () {
        writePackageAsset('assets/logo.png');
        writePackageConfig('my_icons', packageDir);

        expect(
          () => validateAssets(
            specWith(
              const [HWImageData.asset('packages/my_icons/assets/logo.png')],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });

      test('accepts an explicit package parameter', () {
        writePackageAsset('assets/logo.png');
        writePackageConfig('my_icons', packageDir);

        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });

      test('does not require a pubspec declaration for package assets', () {
        writePackageAsset('assets/logo.png');
        writePackageConfig('my_icons', packageDir);
        // Deliberately no pubspec.yaml in the app project.

        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });

      test('rejects a missing file inside a resolved package', () {
        writePackageConfig('my_icons', packageDir);

        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Missing package asset'),
                contains('TestWidget'),
                contains('packages/my_icons/assets/logo.png'),
              ),
            ),
          ),
        );
      });

      test('resolves a rootUri relative to the package config file', () {
        // A relative rootUri like the one `pub get` writes for path deps.
        final relativePackageDir =
            Directory(p.join(projectRoot.path, 'my_icons'));
        final asset =
            File(p.join(relativePackageDir.path, 'lib', 'assets', 'logo.png'));
        asset.parent.createSync(recursive: true);
        asset.writeAsStringSync('png');

        writeProjectFile(
          '.dart_tool/package_config.json',
          '{\n'
              '  "configVersion": 2,\n'
              '  "packages": [\n'
              '    {\n'
              '      "name": "my_icons",\n'
              '      "rootUri": "../my_icons",\n'
              '      "packageUri": "lib/"\n'
              '    }\n'
              '  ]\n'
              '}\n',
        );

        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });

      test('skips validation when package_config.json is absent', () {
        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });

      test('skips validation when the package is not in package_config.json',
          () {
        writePackageConfig('other_package', packageDir);

        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });

      test('skips validation when package_config.json is malformed', () {
        writeProjectFile('.dart_tool/package_config.json', 'not json');

        expect(
          () => validateAssets(
            specWith(
              const [
                HWImageData.asset('assets/logo.png', package: 'my_icons'),
              ],
            ),
            projectRoot,
          ),
          returnsNormally,
        );
      });
    });
  });
}
