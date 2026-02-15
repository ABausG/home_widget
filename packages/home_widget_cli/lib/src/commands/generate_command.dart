import 'dart:io';

import 'package:args/command_runner.dart';

import '../generators/android_generator.dart';
import '../generators/ios_generator.dart';
import '../models/widget_spec.dart';
import '../parser/schema_parser.dart';
import '../util/logger.dart';
import '../util/dependencies.dart';
import '../util/exit_codes.dart';

/// Command that generates native widget code from annotated Dart schemas.
class GenerateCommand extends Command<int> {
  @override
  String get name => 'generate';

  @override
  String get description => 'Generate native widget code from a schema file.';

  /// Creates a new [GenerateCommand].
  GenerateCommand() {
    argParser.addOption(
      'input',
      abbr: 'i',
      help: 'Path to schema file or directory. Defaults to home_widget/',
    );
  }

  @override
  Future<int> run() async {
    final input = argResults?['input'] as String? ?? 'home_widget';
    final inputEntity = FileSystemEntity.isDirectorySync(input)
        ? Directory(input)
        : File(input);

    if (!inputEntity.existsSync()) {
      logger.err('Error: Input path "$input" does not exist.');
      return ExitCodes.noInput;
    }

    final specs = <WidgetSpec>[];

    if (inputEntity is Directory) {
      await for (final file in inputEntity.list(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          try {
            final content = await file.readAsString();
            final spec = await parseSchemaSource(content, filePath: file.path);
            if (spec != null) {
              specs.add(spec);
              logger.info('Parsed ${spec.data.name} from ${file.path}');
            }
          } catch (e) {
            logger.err('Error parsing ${file.path}: $e');
            // Continue parsing other files? Or fail? The plan implies process all.
          }
        }
      }
    } else if (inputEntity is File) {
      try {
        final content = await inputEntity.readAsString();
        final spec =
            await parseSchemaSource(content, filePath: inputEntity.path);
        if (spec != null) {
          specs.add(spec);
          logger.info('Parsed ${spec.data.name} from ${inputEntity.path}');
        } else {
          logger.warn(
            'No @HomeWidget annotation found in ${inputEntity.path}',
          );
        }
      } catch (e) {
        logger.err('Error parsing ${inputEntity.path}: $e');
        return ExitCodes.usage;
      }
    }

    if (specs.isEmpty) {
      logger.info('No widgets found to generate.');
      return ExitCodes.success;
    }

    logger.info('Found ${specs.length} widget(s). Generating...');

    for (final spec in specs) {
      if (spec.data.android != null) {
        logger.info('Generating Android for ${spec.data.name}...');
        await AndroidGenerator(spec: spec, projectRoot: Directory.current)
            .generate();
      }
      if (spec.data.iOS != null) {
        logger.info('Generating iOS for ${spec.data.name}...');
        await IosGenerator(spec: spec, projectRoot: Directory.current)
            .generate();
      }
    }

    // Ensure dependencies are present since generated code depends on home_widget
    await ensureFlutterHomeWidgetDependency(Directory.current);

    return ExitCodes.success;
  }
}
